import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../auth/domain/mobile_auth_session.dart';
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
class PushTokenController extends ChangeNotifier with WidgetsBindingObserver {
  PushTokenController({
    required MobileAuthController authController,
    required NotificationSettingsRepository notificationSettingsRepository,
    required FcmTokenGateway fcmTokenGateway,
    required PushTokenRepository pushTokenRepository,
    bool Function()? registrationAllowed,
    Listenable? registrationGateListenable,
    bool providerReady = true,
  }) : _authController = authController,
       _notificationSettingsRepository = notificationSettingsRepository,
       _fcmTokenGateway = fcmTokenGateway,
       _pushTokenRepository = pushTokenRepository,
       _registrationAllowed = registrationAllowed ?? (() => true),
       _registrationGateListenable = registrationGateListenable,
       _providerReady = providerReady;

  final MobileAuthController _authController;
  final NotificationSettingsRepository _notificationSettingsRepository;
  final FcmTokenGateway _fcmTokenGateway;
  final PushTokenRepository _pushTokenRepository;
  final bool Function() _registrationAllowed;
  final Listenable? _registrationGateListenable;

  PushRegistrationStatus _status = PushRegistrationStatus.idle;
  String? _registeredToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _bootstrapped = false;
  bool _logoutInProgress = false;
  bool _providerReady;
  bool _registrationInFlight = false;
  bool _tokenRegistrationInFlight = false;

  PushRegistrationStatus get status => _status;

  /// The FCM token that was most recently registered with the backend,
  /// or [null] when no registration has succeeded yet.
  String? get registeredToken => _registeredToken;

  /// Starts listening to auth and permission changes and attempts the first
  /// token registration if the user is already authenticated and the optional
  /// registration gate is open. If the platform has not asked for
  /// notification permission yet, the permission request is made explicitly
  /// before obtaining a token. Safe to call multiple times — subsequent calls
  /// are no-ops.
  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }

    _bootstrapped = true;
    _authController.addListener(_onAuthStateChanged);
    _registrationGateListenable?.addListener(_onRegistrationGateChanged);
    WidgetsBinding.instance.addObserver(this);
    _ensureTokenRefreshSubscription();
    await _tryRegisterIfReady();
  }

  /// Signals that the push provider has finished initialization.
  ///
  /// Firebase initialization intentionally happens after the first Flutter
  /// frame. This handshake lets a controller that bootstrapped before Firebase
  /// recover deterministically, while remaining a no-op when called repeatedly.
  void onPushProviderReady() {
    if (!_providerReady) {
      _providerReady = true;
    }
    if (!_bootstrapped) {
      return;
    }
    _ensureTokenRefreshSubscription();
    unawaited(_tryRegisterIfReady());
  }

  /// Re-attempt registration after a previous [PushRegistrationStatus.failed].
  Future<void> retryRegistration() async {
    if (_status == PushRegistrationStatus.registering) {
      return;
    }
    await _tryRegisterIfReady();
  }

  /// Deactivates the current device while the auth session is still valid.
  /// The auth controller calls this before revoking and clearing the session.
  Future<void> prepareForLogout(MobileAuthSession session) async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;

    try {
      await _pushTokenRepository.removeToken(accessToken: session.accessToken);
    } catch (_) {
      // A subsequent authenticated registration atomically rebinds this token
      // to the next user. Logout must remain usable during network failures.
    }
  }

  /// Re-enables registration if the auth logout request itself failed.
  void cancelPendingLogout() {
    _logoutInProgress = false;
    if (_authController.isAuthenticated) {
      unawaited(_tryRegisterIfReady());
    }
  }

  @override
  void dispose() {
    _authController.removeListener(_onAuthStateChanged);
    _registrationGateListenable?.removeListener(_onRegistrationGateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A user may grant notification permission from the system Settings app.
    // Retrying on resume also recovers a registration that failed while the
    // device was offline, without requiring a logout/login cycle.
    if (state == AppLifecycleState.resumed && _authController.isAuthenticated) {
      unawaited(retryRegistration());
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _ensureTokenRefreshSubscription() {
    if (!_providerReady || _tokenRefreshSubscription != null) {
      return;
    }
    _tokenRefreshSubscription = _fcmTokenGateway.onTokenRefresh.listen(
      (newToken) => _registerToken(newToken),
    );
  }

  void _onRegistrationGateChanged() {
    if (_providerReady &&
        _authController.isAuthenticated &&
        _registrationAllowed()) {
      unawaited(_tryRegisterIfReady());
    }
  }

  Future<void> _onAuthStateChanged() async {
    if (_authController.isAuthenticated) {
      await _tryRegisterIfReady();
    } else {
      await _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    if (_logoutInProgress) {
      _logoutInProgress = false;
      _registeredToken = null;
      _setStatus(PushRegistrationStatus.unauthenticated);
      return;
    }

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
    if (_registrationInFlight) {
      return;
    }
    if (!_providerReady) {
      _setStatus(PushRegistrationStatus.unavailable);
      return;
    }
    if (!_registrationAllowed()) {
      // Required onboarding owns the first-run permission moment. The gate
      // listener retries as soon as onboarding completes.
      _setStatus(PushRegistrationStatus.idle);
      return;
    }

    _registrationInFlight = true;
    try {
      final session = _authController.session;
      if (session == null) {
        _setStatus(PushRegistrationStatus.unauthenticated);
        return;
      }

      var permissionStatus = await _notificationSettingsRepository
          .loadPermissionStatus();

      if (permissionStatus == NotificationPermissionStatus.unknown) {
        permissionStatus = await _notificationSettingsRepository
            .requestPermission();
      }

      if (permissionStatus == NotificationPermissionStatus.denied) {
        _setStatus(PushRegistrationStatus.permissionDenied);
        return;
      }

      if (permissionStatus == NotificationPermissionStatus.unavailable) {
        _setStatus(PushRegistrationStatus.unavailable);
        return;
      }
      if (permissionStatus != NotificationPermissionStatus.granted) {
        _setStatus(PushRegistrationStatus.unavailable);
        return;
      }

      _setStatus(PushRegistrationStatus.registering);

      final token = await _fcmTokenGateway.getToken();
      if (token == null) {
        _setStatus(PushRegistrationStatus.unavailable);
        return;
      }

      await _registerToken(
        token,
        accessToken: session.accessToken,
        permissionStatus: permissionStatus,
      );
    } finally {
      _registrationInFlight = false;
    }
  }

  Future<void> _registerToken(
    String token, {
    String? accessToken,
    NotificationPermissionStatus? permissionStatus,
  }) async {
    if (_logoutInProgress ||
        !_providerReady ||
        !_registrationAllowed() ||
        _tokenRegistrationInFlight) {
      return;
    }
    _tokenRegistrationInFlight = true;
    try {
      final resolvedToken = accessToken ?? _authController.session?.accessToken;
      if (resolvedToken == null) {
        _setStatus(PushRegistrationStatus.unauthenticated);
        return;
      }

      _setStatus(PushRegistrationStatus.registering);

      var resolvedPermissionStatus =
          permissionStatus ??
          await _notificationSettingsRepository.loadPermissionStatus();
      if (resolvedPermissionStatus == NotificationPermissionStatus.unknown) {
        resolvedPermissionStatus = await _notificationSettingsRepository
            .requestPermission();
      }
      if (resolvedPermissionStatus == NotificationPermissionStatus.denied) {
        _setStatus(PushRegistrationStatus.permissionDenied);
        return;
      }
      if (resolvedPermissionStatus ==
          NotificationPermissionStatus.unavailable) {
        _setStatus(PushRegistrationStatus.unavailable);
        return;
      }
      if (resolvedPermissionStatus != NotificationPermissionStatus.granted) {
        _setStatus(PushRegistrationStatus.unavailable);
        return;
      }

      final success = await _pushTokenRepository.registerToken(
        token: token,
        platform: defaultTargetPlatform.name.toLowerCase(),
        permissionStatus: resolvedPermissionStatus.name,
        accessToken: resolvedToken,
      );

      if (success) {
        _registeredToken = token;
        _setStatus(PushRegistrationStatus.registered);
      } else {
        _setStatus(PushRegistrationStatus.failed);
      }
    } finally {
      _tokenRegistrationInFlight = false;
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
