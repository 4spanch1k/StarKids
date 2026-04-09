import 'notification_permission_status.dart';

abstract class NotificationSettingsRepository {
  Future<NotificationPermissionStatus> loadPermissionStatus();

  Future<NotificationPermissionStatus> requestPermission();

  Future<bool> openSystemSettings();
}
