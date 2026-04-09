import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_permission_gateway.dart';

class PermissionHandlerNotificationPermissionGateway
    implements NotificationPermissionGateway {
  @override
  Future<DeviceNotificationPermissionStatus> getStatus() async {
    if (!_isSupportedPlatform) {
      return DeviceNotificationPermissionStatus.unavailable;
    }

    try {
      return _mapPermissionStatus(await Permission.notification.status);
    } catch (_) {
      return DeviceNotificationPermissionStatus.unavailable;
    }
  }

  @override
  Future<DeviceNotificationPermissionStatus> requestPermission() async {
    if (!_isSupportedPlatform) {
      return DeviceNotificationPermissionStatus.unavailable;
    }

    try {
      return _mapPermissionStatus(await Permission.notification.request());
    } catch (_) {
      return DeviceNotificationPermissionStatus.unavailable;
    }
  }

  @override
  Future<bool> openSystemSettings() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    try {
      return openAppSettings();
    } catch (_) {
      return false;
    }
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      TargetPlatform.fuchsia => false,
      TargetPlatform.linux => false,
      TargetPlatform.windows => false,
    };
  }

  DeviceNotificationPermissionStatus _mapPermissionStatus(
    PermissionStatus status,
  ) {
    return switch (status) {
      PermissionStatus.granted => DeviceNotificationPermissionStatus.granted,
      PermissionStatus.limited => DeviceNotificationPermissionStatus.granted,
      PermissionStatus.provisional =>
        DeviceNotificationPermissionStatus.granted,
      PermissionStatus.denied => DeviceNotificationPermissionStatus.denied,
      PermissionStatus.permanentlyDenied =>
        DeviceNotificationPermissionStatus.denied,
      PermissionStatus.restricted =>
        DeviceNotificationPermissionStatus.unavailable,
    };
  }
}
