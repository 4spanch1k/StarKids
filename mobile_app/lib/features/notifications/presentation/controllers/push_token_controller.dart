import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/presentation/controllers/mobile_auth_controller.dart';
import '../../data/fcm_token_gateway.dart';
import '../../domain/notification_permission_status.dart';
import '../../domain/notification_settings_repository.dart';
import '../../domain/push_registration_status.dart';
import '../../domain/push_token_repository.dart';

/// Manages FCM token lifecycle: obtains the token, registers it with the
/// backend, listens for token refresh, and removes the token on logout.
///
/// Depends on:
/// - [MobileAuthController] — supplies the access token for backend calls and
///   drives registration on login / deregistration on logout.
/// - [NotificationSettingsRepository] — supplies the current permission status.
/// - [FcmTokenGateway] — fetches and streams FCM tokens.
/// - [PushTokenRepository] — sends/removes tokens via the backend API.
class PushTokenController extends ChangeNotifier {
  PushTokenController({
    required MobileAuthController authController,
    required NotificationSettingsRepository notificationSettingsRepository,
    required FcmTokenGateway fcmTokenGateway,
    required PushTokenRepository pushTokenRepository,
  })  : _authController = authController,
        _notificationSettingsRepository = notificationSettingsRepository,
        _fcmTokenGateway = fcmTokenGateway,
        _pushTokenRepository = pushTokenRepository;

  final MobileAuthController _authController;
  final NotificationSettingsRepository _notificationSettingsRepository;
  final FcmTokenGateway _fcmTokenGateway;
  final PushTokenRepository _pushTokenRepository;

  PushRegistrationStatus _status = PushRegistrationStatus.idle;
  String? _registeredToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _bootstrapped = false;

  PushRegistrationStatus get status => _status;

  /// The FCM token that was most recently registered with the backend,
  /// or [null] when no registration has succeeded yet.
  String? get registeredToken => _registeredToken;

  /// Starts listening to auth and permission changes and attempts the first
  /// token registration if the user is already authenticated and permission is
  /// granted.  Safe to call multiple times — subsequent calls are no-ops.
  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }

    _bootstrapped = true;
    _authController.addListener(_onAuthStateChanged);
    _subscribeToTokenRefresh();
    await _tryRegisterIfReady();
  }

  /// Re-attempt registration after a previous [PushRegistrationStatus.failed].
  Future<void> retryRegistration() async {
    if (_status == PushRegistrationStatus.registering) {
      return;
    }
    await _tryRegisterIfReady();
  }

  @override
  void dispose() {
    _authController.removeListener(_onAuthStateChanged);
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _subscribeToTokenRefresh() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _fcmTokenGateway.onTokenRefresh.listen(
      (newToken) => _registerToken(newToken),
    );
  }

  Future<void> _onAuthStateChanged() async {
    if (_authController.isAuthenticated) {
      await _tryRegisterIfReady();
    } else {
      await _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    final token = _registeredToken;
    _registeredToken = null;

    if (token == null) {
      _setStatus(PushRegistrationStatus.unauthenticated);
      return;
    }

    // Remove token from backend on logout.  Best-effort: no status change on
    // error since the session is already gone.
    try {
      // Access token may be unavailable after logout; skip if so.
      final session = _authController.session;
      if (session != null) {
        await _pushTokenRepository.removeToken(
          accessToken: session.accessToken,
        );
      }
    } catch (_) {
      // Intentionally swallowed.
    }

    _setStatus(PushRegistrationStatus.unauthenticated);
  }

  Future<void> _tryRegisterIfReady() async {
    final session = _authController.session;
    if (session == null) {
      _setStatus(PushRegistrationStatus.unauthenticated);
      return;
    }

    final permissionStatus =
        await _notificationSettingsRepository.loadPermissionStatus();

    if (permissionStatus == NotificationPermissionStatus.denied) {
      _setStatus(PushRegistrationStatus.permissionDenied);
      return;
    }

    if (permissionStatus == NotificationPermissionStatus.unavailable) {
      _setStatus(PushRegistrationStatus.unavailable);
      return;
    }

    // For unknown permission: attempt to get token anyway; the backend call
    // will succeed and the user will be prompted for permission separately.

    _setStatus(PushRegistrationStatus.registering);

    final token = await _fcmTokenGateway.getToken();
    if (token == null) {
      _setStatus(PushRegistrationStatus.unavailable);
      return;
    }

    await _registerToken(token, accessToken: session.accessToken);
  }

  Future<void> _registerToken(
    String token, {
    String? accessToken,
  }) async {
    final resolvedToken = accessToken ?? _authController.session?.accessToken;
    if (resolvedToken == null) {
      _setStatus(PushRegistrationStatus.unauthenticated);
      return;
    }

    _setStatus(PushRegistrationStatus.registering);

    final permissionStatus =
        await _notificationSettingsRepository.loadPermissionStatus();

    final success = await _pushTokenRepository.registerToken(
      token: token,
      platform: defaultTargetPlatform.name.toLowerCase(),
      permissionStatus: permissionStatus.name,
      accessToken: resolvedToken,
    );

    if (success) {
      _registeredToken = token;
      _setStatus(PushRegistrationStatus.registered);
    } else {
      _setStatus(PushRegistrationStatus.failed);
    }
  }

  void _setStatus(PushRegistrationStatus newStatus) {
    if (_status == newStatus) {
      return;
    }

    _status = newStatus;
    notifyListeners();
  }
}
