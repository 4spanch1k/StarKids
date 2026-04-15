import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/theme/app_theme.dart';
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
import 'package:star_kids_mobile/features/notifications/presentation/controllers/mobile_notifications_controller.dart';
import 'package:star_kids_mobile/features/notifications/presentation/controllers/push_token_controller.dart';
import 'package:star_kids_mobile/features/notifications/presentation/pages/notifications_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders permission status and push state labels', (
    WidgetTester tester,
  ) async {
    final controller = MobileNotificationsController(
      repository: const _FakeNotificationSettingsRepository(
        loadStatus: NotificationPermissionStatus.granted,
      ),
    );
    final pushController = _FixedStatusPushTokenController(
      status: PushRegistrationStatus.registered,
    );

    await tester.pumpWidget(_TestApp(
      child: NotificationsPage(
        notificationsController: controller,
        pushTokenController: pushController,
      ),
    ));
    await tester.pump();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Разрешено'), findsWidgets);
    expect(find.text('Регистрация устройства'), findsOneWidget);
    expect(find.text('Зарегистрировано'), findsOneWidget);
    expect(find.text('Токен уведомлений'), findsOneWidget);
    expect(find.text('Активен'), findsOneWidget);
  });

  testWidgets('renders denied permission state with system settings action', (
    WidgetTester tester,
  ) async {
    final controller = MobileNotificationsController(
      repository: const _FakeNotificationSettingsRepository(
        loadStatus: NotificationPermissionStatus.denied,
      ),
    );
    final pushController = _FixedStatusPushTokenController(
      status: PushRegistrationStatus.permissionDenied,
    );

    await tester.pumpWidget(_TestApp(
      child: NotificationsPage(
        notificationsController: controller,
        pushTokenController: pushController,
      ),
    ));
    await tester.pump();

    expect(find.text('Отключено'), findsWidgets);
    expect(find.text('Открыть настройки приложения'), findsOneWidget);
    expect(find.text('Нет разрешения'), findsOneWidget);
  });

  testWidgets('shows retry button when push registration failed', (
    WidgetTester tester,
  ) async {
    final controller = MobileNotificationsController(
      repository: const _FakeNotificationSettingsRepository(
        loadStatus: NotificationPermissionStatus.granted,
      ),
    );
    final pushController = _FixedStatusPushTokenController(
      status: PushRegistrationStatus.failed,
    );

    await tester.pumpWidget(_TestApp(
      child: NotificationsPage(
        notificationsController: controller,
        pushTokenController: pushController,
      ),
    ));
    await tester.pump();

    expect(find.text('Повторить регистрацию'), findsOneWidget);
    expect(find.text('Ошибка регистрации'), findsOneWidget);
    expect(find.text('Не получен'), findsOneWidget);
  });

  testWidgets('shows unauthenticated push state when user not logged in', (
    WidgetTester tester,
  ) async {
    final controller = MobileNotificationsController(
      repository: const _FakeNotificationSettingsRepository(
        loadStatus: NotificationPermissionStatus.unknown,
      ),
    );
    final pushController = _FixedStatusPushTokenController(
      status: PushRegistrationStatus.unauthenticated,
    );

    await tester.pumpWidget(_TestApp(
      child: NotificationsPage(
        notificationsController: controller,
        pushTokenController: pushController,
      ),
    ));
    await tester.pump();

    expect(find.text('Требуется вход'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// Test widget wrapper
// ---------------------------------------------------------------------------

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: child,
    );
  }
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

/// A [PushTokenController] that exposes a fixed status, bypassing all async
/// logic so widget tests can target specific UI states directly.
class _FixedStatusPushTokenController extends PushTokenController {
  _FixedStatusPushTokenController({
    required PushRegistrationStatus status,
  })  : _fixedStatus = status,
        super(
          authController: MobileAuthController(
            repository: _StubAuthRepository(),
          ),
          notificationSettingsRepository:
              const _FakeNotificationSettingsRepository(
            loadStatus: NotificationPermissionStatus.granted,
          ),
          fcmTokenGateway: _NullFcmTokenGateway(),
          pushTokenRepository: _NullPushTokenRepository(),
        );

  final PushRegistrationStatus _fixedStatus;

  @override
  PushRegistrationStatus get status => _fixedStatus;

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> retryRegistration() async {}
}

class _NullFcmTokenGateway implements FcmTokenGateway {
  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class _NullPushTokenRepository implements PushTokenRepository {
  @override
  Future<bool> registerToken({
    required String token,
    required String platform,
    required String permissionStatus,
    required String accessToken,
  }) async =>
      false;

  @override
  Future<void> removeToken({required String accessToken}) async {}
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
