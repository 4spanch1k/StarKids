import 'package:flutter/material.dart';

import '../storage/local_storage.dart';

/// Holds user preferences: locale (language) and theme mode.
/// Persists both to [LocalStorage] backed by [SharedPreferences].
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({required LocalStorage localStorage})
      : _storage = localStorage;

  final LocalStorage _storage;

  String _locale = 'ru'; // 'ru' or 'kk'
  ThemeMode _themeMode = ThemeMode.light;

  String get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  /// Load persisted settings. Call once during app bootstrap.
  Future<void> load() async {
    final savedLocale = await _storage.readLocale();
    if (savedLocale != null && (savedLocale == 'ru' || savedLocale == 'kk')) {
      _locale = savedLocale;
    }

    final savedTheme = await _storage.readThemeMode();
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }

    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    if (_locale == languageCode) return;
    _locale = languageCode;
    notifyListeners();
    await _storage.saveLocale(languageCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.saveThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
