import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/theme/app_theme.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_permission_status.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_settings_repository.dart';
import 'package:star_kids_mobile/features/notifications/presentation/controllers/mobile_notifications_controller.dart';
import 'package:star_kids_mobile/features/notifications/presentation/pages/notifications_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders granted state and backend blocker honestly', (
    WidgetTester tester,
  ) async {
    final controller = MobileNotificationsController(
      repository: const _FakeNotificationSettingsRepository(
        loadStatus: NotificationPermissionStatus.granted,
      ),
    );

    await tester.pumpWidget(_TestApp(
      child: NotificationsPage(notificationsController: controller),
    ));
    await tester.pump();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Разрешено'), findsWidgets);
    expect(find.text('Регистрация устройства в backend'), findsOneWidget);
    expect(find.text('Не подключена'), findsOneWidget);
    expect(find.text('Push token'), findsOneWidget);
    expect(find.text('Не используется'), findsOneWidget);
    expect(find.text('Открыть настройки приложения'), findsOneWidget);
  });

  testWidgets('renders denied state with system settings action', (
    WidgetTester tester,
  ) async {
    final controller = MobileNotificationsController(
      repository: const _FakeNotificationSettingsRepository(
        loadStatus: NotificationPermissionStatus.denied,
      ),
    );

    await tester.pumpWidget(_TestApp(
      child: NotificationsPage(notificationsController: controller),
    ));
    await tester.pump();

    expect(find.text('Отключено'), findsWidgets);
    expect(find.text('Открыть настройки приложения'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: child,
    );
  }
}

class _FakeNotificationSettingsRepository
    implements NotificationSettingsRepository {
  const _FakeNotificationSettingsRepository({
    required this.loadStatus,
  });

  final NotificationPermissionStatus loadStatus;

  @override
  Future<NotificationPermissionStatus> loadPermissionStatus() async {
    return loadStatus;
  }

  @override
  Future<bool> openSystemSettings() async {
    return true;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    return loadStatus;
  }
}
