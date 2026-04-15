import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_repository.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_session.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_user.dart';
import 'package:star_kids_mobile/features/auth/domain/otp_challenge.dart';
import 'package:star_kids_mobile/features/auth/presentation/controllers/mobile_auth_controller.dart';
import 'package:star_kids_mobile/features/notifications/data/fcm_token_gateway.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_permission_status.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_settings_repository.dart';
import 'package:star_kids_mobile/features/notifications/domain/push_registration_status.dart';
import 'package:star_kids_mobile/features/notifications/domain/push_token_repository.dart';
import 'package:star_kids_mobile/features/notifications/presentation/controllers/push_token_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushTokenController', () {
    test('bootstrap → unauthenticated when user is not logged in', () async {
      final authController = _buildAuthController(session: null);
      final controller = _buildPushController(
        authController: authController,
        permissionStatus: NotificationPermissionStatus.granted,
        fcmToken: 'token-1',
        registerSuccess: true,
      );

      await controller.bootstrap();

      expect(controller.status, PushRegistrationStatus.unauthenticated);
      expect(controller.registeredToken, isNull);
    });

    test('bootstrap → registered when authenticated + permission granted + token available',
        () async {
      final session = _buildSession('access-token-1');
      final authController = _buildAuthController(session: session);
      final controller = _buildPushController(
        authController: authController,
        permissionStatus: NotificationPermissionStatus.granted,
        fcmToken: 'fcm-token-abc',
        registerSuccess: true,
      );

      await controller.bootstrap();

      expect(controller.status, PushRegistrationStatus.registered);
      expect(controller.registeredToken, 'fcm-token-abc');
    });

    test('bootstrap → failed when backend rejects token', () async {
      final session = _buildSession('access-token-2');
      final authController = _buildAuthController(session: session);
      final controller = _buildPushController(
        authController: authController,
        permissionStatus: NotificationPermissionStatus.granted,
        fcmToken: 'fcm-token-xyz',
        registerSuccess: false,
      );

      await controller.bootstrap();

      expect(controller.status, PushRegistrationStatus.failed);
      expect(controller.registeredToken, isNull);
    });

    test('bootstrap → permissionDenied when permission is denied', () async {
      final session = _buildSession('access-token-3');
      final authController = _buildAuthController(session: session);
      final controller = _buildPushController(
        authController: authController,
        permissionStatus: NotificationPermissionStatus.denied,
        fcmToken: 'fcm-token',
        registerSuccess: true,
      );

      await controller.bootstrap();

      expect(controller.status, PushRegistrationStatus.permissionDenied);
    });

    test('bootstrap → unavailable when FCM token is null (Firebase not configured)',
        () async {
      final session = _buildSession('access-token-4');
      final authController = _buildAuthController(session: session);
      final controller = _buildPushController(
        authController: authController,
        permissionStatus: NotificationPermissionStatus.granted,
        fcmToken: null,
        registerSuccess: true,
      );

      await controller.bootstrap();

      expect(controller.status, PushRegistrationStatus.unavailable);
    });

    test('token refresh triggers re-registration with new token', () async {
      final session = _buildSession('access-token-5');
      final authController = _buildAuthController(session: session);
      final tokenStreamController = StreamController<String>();
      final fcmGateway = _StreamableFcmTokenGateway(
        initialToken: 'initial-token',
        refreshStream: tokenStreamController.stream,
      );
      final pushRepo = _RecordingPushTokenRepository(success: true);
      final controller = PushTokenController(
        authController: authController,
        notificationSettingsRepository: _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.granted,
        ),
        fcmTokenGateway: fcmGateway,
        pushTokenRepository: pushRepo,
      );

      await controller.bootstrap();
      expect(controller.status, PushRegistrationStatus.registered);
      expect(controller.registeredToken, 'initial-token');

      // Simulate FCM token refresh.
      tokenStreamController.add('refreshed-token');
      // Let async listeners run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.registeredToken, 'refreshed-token');
      expect(controller.status, PushRegistrationStatus.registered);
      expect(pushRepo.registeredTokens.length, 2);
      expect(pushRepo.registeredTokens.last, 'refreshed-token');

      await tokenStreamController.close();
      controller.dispose();
    });

    test('logout removes registered token and sets unauthenticated', () async {
      final session = _buildSession('access-token-6');
      final authController = _buildAuthController(session: session);
      final pushRepo = _RecordingPushTokenRepository(success: true);

      final controller = PushTokenController(
        authController: authController,
        notificationSettingsRepository: _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.granted,
        ),
        fcmTokenGateway: _FakeFcmTokenGateway(token: 'my-token'),
        pushTokenRepository: pushRepo,
      );

      await controller.bootstrap();
      expect(controller.status, PushRegistrationStatus.registered);

      // Simulate logout: session becomes null and auth controller notifies.
      authController.setSessionForTest(null);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, PushRegistrationStatus.unauthenticated);
      expect(controller.registeredToken, isNull);
    });

    test('retryRegistration re-attempts when in failed state', () async {
      final session = _buildSession('access-token-7');
      final authController = _buildAuthController(session: session);
      int callCount = 0;
      final pushRepo = _CallbackPushTokenRepository(
        onRegister: (_) async {
          callCount += 1;
          return callCount >= 2; // fails first, succeeds second
        },
      );

      final controller = PushTokenController(
        authController: authController,
        notificationSettingsRepository: _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.granted,
        ),
        fcmTokenGateway: _FakeFcmTokenGateway(token: 'retry-token'),
        pushTokenRepository: pushRepo,
      );

      await controller.bootstrap();
      expect(controller.status, PushRegistrationStatus.failed);

      await controller.retryRegistration();
      expect(controller.status, PushRegistrationStatus.registered);
      expect(controller.registeredToken, 'retry-token');
    });

    test('bootstrap is idempotent — second call is no-op', () async {
      final session = _buildSession('access-token-8');
      final authController = _buildAuthController(session: session);
      int getTokenCallCount = 0;
      final gateway = _CountingFcmTokenGateway(
        token: 'counted-token',
        onGetToken: () => getTokenCallCount++,
      );
      final controller = PushTokenController(
        authController: authController,
        notificationSettingsRepository: _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.granted,
        ),
        fcmTokenGateway: gateway,
        pushTokenRepository: _FakePushTokenRepository(success: true),
      );

      await controller.bootstrap();
      await controller.bootstrap();
      await controller.bootstrap();

      expect(getTokenCallCount, 1);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MobileAuthSession _buildSession(String accessToken) {
  return MobileAuthSession(
    user: const MobileAuthUser(id: 'user-1', phone: '+77071234567'),
    phone: '+77071234567',
    accessToken: accessToken,
    refreshToken: 'refresh',
    tokenType: 'bearer',
    verifiedAt: DateTime(2026, 1, 1),
  );
}

/// A testable [MobileAuthController] that allows overriding the session.
class _TestableAuthController extends MobileAuthController {
  _TestableAuthController({MobileAuthSession? session})
      : super(repository: _StubAuthRepository()) {
    _testSession = session;
  }

  MobileAuthSession? _testSession;

  @override
  MobileAuthSession? get session => _testSession;

  @override
  bool get isAuthenticated => _testSession != null;

  void setSessionForTest(MobileAuthSession? session) {
    _testSession = session;
    notifyListeners();
  }
}

_TestableAuthController _buildAuthController({MobileAuthSession? session}) {
  return _TestableAuthController(session: session);
}

PushTokenController _buildPushController({
  required MobileAuthController authController,
  required NotificationPermissionStatus permissionStatus,
  required String? fcmToken,
  required bool registerSuccess,
}) {
  return PushTokenController(
    authController: authController,
    notificationSettingsRepository: _FakeNotificationSettingsRepository(
      loadStatus: permissionStatus,
    ),
    fcmTokenGateway: _FakeFcmTokenGateway(token: fcmToken),
    pushTokenRepository: _FakePushTokenRepository(success: registerSuccess),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeNotificationSettingsRepository
    implements NotificationSettingsRepository {
  const _FakeNotificationSettingsRepository({
    required this.loadStatus,
  });

  final NotificationPermissionStatus loadStatus;

  @override
  Future<NotificationPermissionStatus> loadPermissionStatus() async =>
      loadStatus;

  @override
  Future<bool> openSystemSettings() async => true;

  @override
  Future<NotificationPermissionStatus> requestPermission() async => loadStatus;
}

class _FakeFcmTokenGateway implements FcmTokenGateway {
  _FakeFcmTokenGateway({required this.token});

  final String? token;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class _FakePushTokenRepository implements PushTokenRepository {
  _FakePushTokenRepository({required this.success});

  final bool success;

  @override
  Future<bool> registerToken({
    required String token,
    required String platform,
    required String permissionStatus,
    required String accessToken,
  }) async =>
      success;

  @override
  Future<void> removeToken({required String accessToken}) async {}
}

class _RecordingPushTokenRepository implements PushTokenRepository {
  _RecordingPushTokenRepository({required this.success});

  final bool success;
  final List<String> registeredTokens = [];

  @override
  Future<bool> registerToken({
    required String token,
    required String platform,
    required String permissionStatus,
    required String accessToken,
  }) async {
    registeredTokens.add(token);
    return success;
  }

  @override
  Future<void> removeToken({required String accessToken}) async {}
}

class _CallbackPushTokenRepository implements PushTokenRepository {
  _CallbackPushTokenRepository({required this.onRegister});

  final Future<bool> Function(String token) onRegister;

  @override
  Future<bool> registerToken({
    required String token,
    required String platform,
    required String permissionStatus,
    required String accessToken,
  }) =>
      onRegister(token);

  @override
  Future<void> removeToken({required String accessToken}) async {}
}

class _StreamableFcmTokenGateway implements FcmTokenGateway {
  _StreamableFcmTokenGateway({
    required this.initialToken,
    required this.refreshStream,
  });

  final String? initialToken;
  final Stream<String> refreshStream;

  @override
  Future<String?> getToken() async => initialToken;

  @override
  Stream<String> get onTokenRefresh => refreshStream;
}

class _CountingFcmTokenGateway implements FcmTokenGateway {
  _CountingFcmTokenGateway({required this.token, required this.onGetToken});

  final String? token;
  final void Function() onGetToken;

  @override
  Future<String?> getToken() async {
    onGetToken();
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class _StubAuthRepository implements MobileAuthRepository {
  @override
  Future<void> clearSession() async {}

  @override
  Future<Result<MobileAuthUser>> getCurrentUser(String accessToken) async =>
      const Failure('stub');

  @override
  Future<Result<void>> logout(MobileAuthSession session) async =>
      const Success(null);

  @override
  Future<Result<OtpChallenge>> requestOtp(String phone) async =>
      const Failure('stub');

  @override
  Future<Result<MobileAuthSession>> refreshSession(String refreshToken) async =>
      const Failure('stub');

  @override
  Future<MobileAuthSession?> restoreSession() async => null;

  @override
  Future<Result<MobileAuthSession?>> syncSession(
    MobileAuthSession session,
  ) async =>
      const Success(null);

  @override
  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  }) async =>
      const Failure('stub');

  @override
  Future<Result<MobileAuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) async =>
      const Failure('stub');

  @override
  Future<Result<MobileAuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async =>
      const Failure('stub');
}
