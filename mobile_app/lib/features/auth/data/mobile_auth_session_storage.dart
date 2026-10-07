import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/mobile_auth_session.dart';
import '../domain/mobile_auth_user.dart';

/// Stores the mobile session in Keychain/Keystore-backed secure storage.
///
/// The SharedPreferences blob is read only as a one-time migration source for
/// users of the pre-OTP app. It is removed after the secure write succeeds.
class MobileAuthSessionStorage {
  static const _legacySessionKey = 'mobile_auth_session';
  static const _secureSessionKey = 'mobile_auth_session_v2';
  String? _testFallbackValue;

  MobileAuthSessionStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage;

  FlutterSecureStorage? _secureStorage;

  FlutterSecureStorage get _platformStorage =>
      _secureStorage ??= const FlutterSecureStorage();

  Future<void> saveSession(MobileAuthSession session) async {
    final raw = jsonEncode(_encodeSession(session));
    final secureWriteSucceeded = await _writeSecure(raw);
    final preferences = await SharedPreferences.getInstance();
    if (secureWriteSucceeded) {
      await preferences.remove(_legacySessionKey);
    }
  }

  Future<MobileAuthSession?> readSession() async {
    var raw = await _readSecure();
    if (raw == null || raw.trim().isEmpty) {
      final preferences = await SharedPreferences.getInstance();
      final legacy = preferences.getString(_legacySessionKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        if (await _writeSecure(legacy)) {
          await preferences.remove(_legacySessionKey);
        }
        raw = legacy;
      }
    }
    return raw == null ? null : _decodeSession(raw);
  }

  Future<void> clearSession() async {
    if (!_hasServicesBinding) {
      _testFallbackValue = null;
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_legacySessionKey);
      return;
    }
    try {
      await _platformStorage
          .delete(key: _secureSessionKey)
          .timeout(_platformTimeout);
    } on MissingPluginException {
      _testFallbackValue = null;
    } on TimeoutException {
      _testFallbackValue = null;
    } on PlatformException catch (error) {
      if (error.code == 'MissingPluginException') {
        _testFallbackValue = null;
      } else {
        rethrow;
      }
    }
    _testFallbackValue = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacySessionKey);
  }

  Future<bool> _writeSecure(String value) async {
    if (!_hasServicesBinding) {
      _testFallbackValue = value;
      return true;
    }
    try {
      await _platformStorage
          .write(key: _secureSessionKey, value: value)
          .timeout(_platformTimeout);
      return true;
    } on MissingPluginException {
      _testFallbackValue = value;
      return false;
    } on TimeoutException {
      _testFallbackValue = value;
      return false;
    } on PlatformException catch (error) {
      if (error.code == 'MissingPluginException') {
        _testFallbackValue = value;
        return false;
      } else {
        rethrow;
      }
    }
  }

  Future<String?> _readSecure() async {
    if (!_hasServicesBinding) return _testFallbackValue;
    try {
      return await _platformStorage
          .read(key: _secureSessionKey)
          .timeout(_platformTimeout);
    } on MissingPluginException {
      return _testFallbackValue;
    } on TimeoutException {
      return _testFallbackValue;
    } on PlatformException catch (error) {
      if (error.code == 'MissingPluginException') {
        return _testFallbackValue;
      }
      rethrow;
    }
  }

  bool get _hasServicesBinding {
    try {
      ServicesBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Duration get _platformTimeout => kDebugMode
      ? const Duration(milliseconds: 100)
      : const Duration(seconds: 2);

  static Map<String, dynamic> _encodeSession(MobileAuthSession session) {
    return {
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
    };
  }

  static MobileAuthSession? _decodeSession(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final phone = json['phone'] as String?;
      final email = json['email'] as String?;
      final accessToken = json['accessToken'] as String?;
      final refreshToken = json['refreshToken'] as String?;
      final tokenType = (json['tokenType'] as String?) ?? 'bearer';
      final accessExpiresAtRaw = json['accessExpiresAt'] as String?;
      final refreshExpiresAtRaw = json['refreshExpiresAt'] as String?;
      final verifiedAtRaw = json['verifiedAt'] as String?;
      if ((phone == null && email == null) ||
          accessToken == null ||
          refreshToken == null ||
          verifiedAtRaw == null) {
        return null;
      }

      MobileAuthUser? user;
      final userJson = json['user'];
      if (userJson is Map<String, dynamic>) {
        final id = userJson['id'] as String?;
        final userPhone = userJson['phone'] as String?;
        final userEmail = userJson['email'] as String?;
        if (id != null && (userPhone != null || userEmail != null)) {
          user = MobileAuthUser(id: id, phone: userPhone, email: userEmail);
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
