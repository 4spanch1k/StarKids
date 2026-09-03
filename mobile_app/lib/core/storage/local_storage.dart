import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _preferredBranchKey = 'preferred_branch_id';
  static const _localeKey = 'app_locale';
  static const _themeModeKey = 'app_theme_mode';

  // ─── Branch ───────────────────────────────────────────────────────────────

  Future<void> savePreferredBranch(String branchId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferredBranchKey, branchId);
  }

  Future<String?> readPreferredBranch() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_preferredBranchKey);
  }

  // ─── Locale ───────────────────────────────────────────────────────────────

  /// Saves locale language code, e.g. 'ru' or 'kk'.
  Future<void> saveLocale(String languageCode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localeKey, languageCode);
  }

  Future<String?> readLocale() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_localeKey);
  }

  // ─── Theme mode ───────────────────────────────────────────────────────────

  /// Saves 'light' or 'dark'.
  Future<void> saveThemeMode(String mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, mode);
  }

  Future<String?> readThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_themeModeKey);
  }
}
