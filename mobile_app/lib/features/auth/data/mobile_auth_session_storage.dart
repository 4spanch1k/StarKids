import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/mobile_auth_user.dart';
import '../domain/mobile_auth_session.dart';

class MobileAuthSessionStorage {
  static const _sessionKey = 'mobile_auth_session';

  Future<void> saveSession(MobileAuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sessionKey,
      jsonEncode({
        'user': session.user == null
            ? null
            : {
                'id': session.user!.id,
                'phone': session.user!.phone,
                'email': session.user!.email,
              },
        'phone': session.phone,
        'email': session.email,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'tokenType': session.tokenType,
        'accessExpiresAt': session.accessExpiresAt?.toIso8601String(),
        'refreshExpiresAt': session.refreshExpiresAt?.toIso8601String(),
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
      final email = json['email'] as String?;
      final accessToken = json['accessToken'] as String?;
      final refreshToken = json['refreshToken'] as String?;
      final tokenType = (json['tokenType'] as String?) ?? 'bearer';
      final accessExpiresAtRaw = json['accessExpiresAt'] as String?;
      final refreshExpiresAtRaw = json['refreshExpiresAt'] as String?;
      final verifiedAtRaw = json['verifiedAt'] as String?;
      final userJson = json['user'];

      if ((phone == null && email == null) ||
          accessToken == null ||
          refreshToken == null ||
          verifiedAtRaw == null) {
        return null;
      }

      MobileAuthUser? user;
      if (userJson is Map<String, dynamic>) {
        final id = userJson['id'] as String?;
        final userPhone = userJson['phone'] as String?;
        final userEmail = userJson['email'] as String?;
        if (id != null && (userPhone != null || userEmail != null)) {
          user = MobileAuthUser(
            id: id,
            phone: userPhone,
            email: userEmail,
          );
        }
      }

      return MobileAuthSession(
        user: user,
        phone: phone,
        email: email,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenType: tokenType,
        accessExpiresAt: accessExpiresAtRaw == null
            ? null
            : DateTime.parse(accessExpiresAtRaw),
        refreshExpiresAt: refreshExpiresAtRaw == null
            ? null
            : DateTime.parse(refreshExpiresAtRaw),
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
