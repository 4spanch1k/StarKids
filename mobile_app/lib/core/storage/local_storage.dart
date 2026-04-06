import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _preferredBranchKey = 'preferred_branch_id';

  Future<void> savePreferredBranch(String branchId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferredBranchKey, branchId);
  }

  Future<String?> readPreferredBranch() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_preferredBranchKey);
  }
}
