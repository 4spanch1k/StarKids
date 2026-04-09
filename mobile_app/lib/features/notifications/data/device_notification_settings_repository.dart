import '../domain/notification_permission_status.dart';
import '../domain/notification_settings_repository.dart';
import 'notification_permission_gateway.dart';
import 'notification_permission_storage.dart';

class DeviceNotificationSettingsRepository
    implements NotificationSettingsRepository {
  DeviceNotificationSettingsRepository({
    required NotificationPermissionStorage storage,
    required NotificationPermissionGateway permissionGateway,
  })  : _storage = storage,
        _permissionGateway = permissionGateway;

  final NotificationPermissionStorage _storage;
  final NotificationPermissionGateway _permissionGateway;

  @override
  Future<NotificationPermissionStatus> loadPermissionStatus() async {
    final hasRequestedPermission = await _storage.hasRequestedPermission();
    final deviceStatus = await _permissionGateway.getStatus();
    return _mapStatus(
      deviceStatus,
      hasRequestedPermission: hasRequestedPermission,
    );
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final currentStatus = await _permissionGateway.getStatus();
    if (currentStatus == DeviceNotificationPermissionStatus.unavailable) {
      return NotificationPermissionStatus.unavailable;
    }

    await _storage.markPermissionRequested();
    final requestedStatus = await _permissionGateway.requestPermission();
    return _mapStatus(requestedStatus, hasRequestedPermission: true);
  }

  @override
  Future<bool> openSystemSettings() {
    return _permissionGateway.openSystemSettings();
  }

  NotificationPermissionStatus _mapStatus(
    DeviceNotificationPermissionStatus deviceStatus, {
    required bool hasRequestedPermission,
  }) {
    return switch (deviceStatus) {
      DeviceNotificationPermissionStatus.granted =>
        NotificationPermissionStatus.granted,
      DeviceNotificationPermissionStatus.denied => hasRequestedPermission
          ? NotificationPermissionStatus.denied
          : NotificationPermissionStatus.unknown,
      DeviceNotificationPermissionStatus.unavailable =>
        NotificationPermissionStatus.unavailable,
    };
  }
}
