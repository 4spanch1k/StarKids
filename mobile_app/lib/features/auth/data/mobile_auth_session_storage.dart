import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/mobile_auth_session.dart';
import '../domain/mobile_auth_user.dart';
import 'secure_storage_adapter.dart';

class MobileAuthSessionStorage {
  MobileAuthSessionStorage({SecureStorageAdapter? secureStorage})
      : _secureStorage = secureStorage ?? FlutterSecureStorageAdapter();

  static const legacySessionKey = 'mobile_auth_session';
  static const secureSessionKey = 'mobile_auth_session_secure';

  final SecureStorageAdapter _secureStorage;

  Future<void> saveSession(MobileAuthSession session) async {
    final serialized = _serializeSession(session);

    // Secure persistence is the only credential write. If it fails, the
    // legacy value is deliberately left untouched so migration can be retried
    // later, but no new plaintext copy is created.
    await _secureStorage.write(secureSessionKey, serialized);
    await _bestEffortRemoveLegacySession();
  }

  Future<MobileAuthSession?> readSession() async {
    String? secureRaw;
    try {
      secureRaw = await _secureStorage.read(secureSessionKey);
    } catch (_) {
      // A secure-storage failure must never fall back to plaintext credentials.
      return null;
    }

    if (secureRaw != null) {
      final secureSession = _deserializeSession(secureRaw);
      if (secureSession != null) {
        // A legacy value can be left behind by an interrupted upgrade. It is
        // safe to remove it now because the secure source is authoritative.
        await _bestEffortRemoveLegacySession();
        return secureSession;
      }

      // Do not resurrect a stale legacy session when the secure entry is
      // present but unusable. Removing it is best effort; the safe result is
      // still unauthenticated.
      try {
        await _secureStorage.delete(secureSessionKey);
      } catch (_) {
        // Ignore cleanup failure and keep the safe null result.
      }
      await _bestEffortRemoveLegacySession();
      return null;
    }

    final preferences = await SharedPreferences.getInstance();
    final legacyRaw = preferences.getString(legacySessionKey);
    if (legacyRaw == null || legacyRaw.trim().isEmpty) {
      return null;
    }

    final legacySession = _deserializeSession(legacyRaw);
    if (legacySession == null) {
      return null;
    }

    // Migration is intentionally ordered write-then-delete. A failed secure
    // write leaves the legacy value available for a later retry.
    try {
      await _secureStorage.write(
        secureSessionKey,
        _serializeSession(legacySession),
      );
    } catch (_) {
      return null;
    }

    await preferences.remove(legacySessionKey);
    return legacySession;
  }

  Future<void> clearSession() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    try {
      await _secureStorage.delete(secureSessionKey);
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(legacySessionKey);
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    if (firstError != null) {
      Error.throwWithStackTrace(
        firstError,
        firstStackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> _bestEffortRemoveLegacySession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(legacySessionKey);
    } catch (_) {
      // Secure storage remains authoritative even if legacy cleanup is
      // temporarily unavailable.
    }
  }

  static String _serializeSession(MobileAuthSession session) {
    return jsonEncode({
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
    });
  }

  static MobileAuthSession? _deserializeSession(String raw) {
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

      final hasIdentity = (phone != null && phone.trim().isNotEmpty) ||
          (email != null && email.trim().isNotEmpty);
      if (!hasIdentity ||
          accessToken == null ||
          accessToken.trim().isEmpty ||
          refreshToken == null ||
          refreshToken.trim().isEmpty ||
          verifiedAtRaw == null ||
          verifiedAtRaw.trim().isEmpty) {
        return null;
      }

      MobileAuthUser? user;
      if (userJson is Map<String, dynamic>) {
        final id = userJson['id'] as String?;
        final userPhone = userJson['phone'] as String?;
        final userEmail = userJson['email'] as String?;
        final hasUserIdentity =
            (userPhone != null && userPhone.trim().isNotEmpty) ||
                (userEmail != null && userEmail.trim().isNotEmpty);
        if (id != null && id.trim().isNotEmpty && hasUserIdentity) {
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
}
