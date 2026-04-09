import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/theme/app_theme.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_permission_status.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_settings_repository.dart';
import 'package:star_kids_mobile/features/notifications/presentation/controllers/mobile_notifications_controller.dart';
import 'package:star_kids_mobile/features/profile/presentation/pages/profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile page shows minimal notifications status entry point', (
    WidgetTester tester,
  ) async {
    final controller = MobileNotificationsController(
      repository: const _FakeNotificationSettingsRepository(
        loadStatus: NotificationPermissionStatus.denied,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProfilePage(notificationsController: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Статус уведомлений'), findsOneWidget);
    expect(find.text('Отключено'), findsOneWidget);
  });
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
