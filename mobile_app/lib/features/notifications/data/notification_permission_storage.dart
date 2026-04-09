import 'package:shared_preferences/shared_preferences.dart';

class NotificationPermissionStorage {
  static const _permissionRequestedKey = 'notifications_permission_requested';

  Future<bool> hasRequestedPermission() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_permissionRequestedKey) ?? false;
  }

  Future<void> markPermissionRequested() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_permissionRequestedKey, true);
  }
}
