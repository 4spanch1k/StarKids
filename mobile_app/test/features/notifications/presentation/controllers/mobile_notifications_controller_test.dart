import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/notifications/domain/notification_permission_status.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_settings_repository.dart';
import 'package:star_kids_mobile/features/notifications/presentation/controllers/mobile_notifications_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MobileNotificationsController', () {
    test('bootstrap loads unknown permission state', () async {
      final controller = MobileNotificationsController(
        repository: _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.unknown,
        ),
      );

      await controller.bootstrap();

      expect(controller.status, NotificationPermissionStatus.unknown);
      expect(controller.isLoading, isFalse);
    });

    test('requestPermission updates controller to granted', () async {
      final repository = _FakeNotificationSettingsRepository(
        loadStatus: NotificationPermissionStatus.unknown,
        requestedStatus: NotificationPermissionStatus.granted,
      );
      final controller = MobileNotificationsController(repository: repository);

      await controller.bootstrap();
      await controller.requestPermission();

      expect(controller.status, NotificationPermissionStatus.granted);
      expect(repository.requestPermissionCallCount, 1);
    });

    test('bootstrap can expose denied and unavailable states', () async {
      final deniedController = MobileNotificationsController(
        repository: _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.denied,
        ),
      );
      final unavailableController = MobileNotificationsController(
        repository: _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.unavailable,
        ),
      );

      await deniedController.bootstrap();
      await unavailableController.bootstrap();

      expect(deniedController.status, NotificationPermissionStatus.denied);
      expect(
        unavailableController.status,
        NotificationPermissionStatus.unavailable,
      );
    });
  });
}

class _FakeNotificationSettingsRepository
    implements NotificationSettingsRepository {
  _FakeNotificationSettingsRepository({
    required this.loadStatus,
    NotificationPermissionStatus? requestedStatus,
  }) : _requestedStatus = requestedStatus ?? loadStatus;

  final NotificationPermissionStatus loadStatus;
  final NotificationPermissionStatus _requestedStatus;

  int requestPermissionCallCount = 0;

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
    requestPermissionCallCount += 1;
    return _requestedStatus;
  }
}
