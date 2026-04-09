enum DeviceNotificationPermissionStatus {
  granted,
  denied,
  unavailable,
}

abstract class NotificationPermissionGateway {
  Future<DeviceNotificationPermissionStatus> getStatus();

  Future<DeviceNotificationPermissionStatus> requestPermission();

  Future<bool> openSystemSettings();
}
