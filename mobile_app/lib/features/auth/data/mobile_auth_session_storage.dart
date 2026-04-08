import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/mobile_auth_session.dart';

class MobileAuthSessionStorage {
  static const _sessionKey = 'mobile_auth_session';

  Future<void> saveSession(MobileAuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sessionKey,
      jsonEncode({
        'phone': session.phone,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'verifiedAt': session.verifiedAt.toIso8601String(),
      }),
    );
  }

  Future<MobileAuthSession?> readSession() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sessionKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return null;
      }

      final phone = json['phone'] as String?;
      final accessToken = json['accessToken'] as String?;
      final refreshToken = json['refreshToken'] as String?;
      final verifiedAtRaw = json['verifiedAt'] as String?;

      if (phone == null ||
          accessToken == null ||
          refreshToken == null ||
          verifiedAtRaw == null) {
        return null;
      }

      return MobileAuthSession(
        phone: phone,
        accessToken: accessToken,
        refreshToken: refreshToken,
        verifiedAt: DateTime.parse(verifiedAtRaw),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
