import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:star_kids_mobile/features/auth/data/mobile_auth_session_storage.dart';
import 'package:star_kids_mobile/features/auth/data/secure_storage_adapter.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_session.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_user.dart';

void main() {
  late InMemorySecureStorage secureStorage;
  late MobileAuthSessionStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage = InMemorySecureStorage();
    storage = MobileAuthSessionStorage(secureStorage: secureStorage);
  });

  test('saveSession persists the complete session only in secure storage',
      () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      'legacy-copy',
    );

    final session = _session();
    await storage.saveSession(session);

    final encoded =
        secureStorage.values[MobileAuthSessionStorage.secureSessionKey];
    expect(encoded, isNotNull);
    final json = jsonDecode(encoded!) as Map<String, dynamic>;
    expect(json['accessToken'], session.accessToken);
    expect(json['refreshToken'], session.refreshToken);
    expect(json['tokenType'], session.tokenType);
    expect(json['accessExpiresAt'], session.accessExpiresAt!.toIso8601String());
    expect(
      json['refreshExpiresAt'],
      session.refreshExpiresAt!.toIso8601String(),
    );
    expect(json['verifiedAt'], session.verifiedAt.toIso8601String());
    expect(json['user']['id'], session.user!.id);
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNull,
    );
  });

  test('readSession returns a valid secure session and takes precedence',
      () async {
    final secureSession = _session(accessToken: 'secure-access');
    final legacySession = _session(accessToken: 'legacy-access');
    secureStorage.values[MobileAuthSessionStorage.secureSessionKey] =
        _encode(secureSession);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      _encode(legacySession),
    );

    final result = await storage.readSession();

    expect(result?.accessToken, 'secure-access');
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNull,
    );
  });

  test('migrates a valid legacy session only after secure write succeeds',
      () async {
    final legacy = _session();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      _encode(legacy),
    );

    final result = await storage.readSession();

    expect(result?.accessToken, legacy.accessToken);
    final migrated = jsonDecode(
      secureStorage.values[MobileAuthSessionStorage.secureSessionKey]!,
    ) as Map<String, dynamic>;
    expect(migrated['accessToken'], legacy.accessToken);
    expect(migrated['tokenType'], 'bearer');
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNull,
    );
  });

  test('accepts the original phone-only legacy session shape', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      jsonEncode({
        'phone': '+77071234567',
        'accessToken': 'legacy-access',
        'refreshToken': 'legacy-refresh',
        'verifiedAt': '2026-09-14T00:00:00Z',
      }),
    );

    final result = await storage.readSession();

    expect(result?.phone, '+77071234567');
    expect(result?.accessToken, 'legacy-access');
    expect(result?.tokenType, 'bearer');
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNull,
    );
  });

  test('accepts email-only legacy sessions from email authentication',
      () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      jsonEncode({
        'email': 'legacy@example.com',
        'accessToken': 'legacy-access',
        'refreshToken': 'legacy-refresh',
        'tokenType': 'bearer',
        'verifiedAt': '2026-09-14T00:00:00Z',
      }),
    );

    final result = await storage.readSession();

    expect(result?.email, 'legacy@example.com');
    expect(result?.phone, isNull);
    expect(result?.accessToken, 'legacy-access');
  });

  test('migration write failure preserves legacy and never falls back',
      () async {
    final legacy = _session();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      _encode(legacy),
    );
    secureStorage.throwOnWrite = true;

    final result = await storage.readSession();

    expect(result, isNull);
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      _encode(legacy),
    );
    expect(
      secureStorage.values[MobileAuthSessionStorage.secureSessionKey],
      isNull,
    );
  });

  test('saveSession failure never writes a plaintext copy', () async {
    final preferences = await SharedPreferences.getInstance();
    secureStorage.throwOnWrite = true;

    await expectLater(
        storage.saveSession(_session()), throwsA(isA<StateError>()));

    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNull,
    );
  });

  test('secure read failure does not resurrect legacy plaintext', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      _encode(_session()),
    );
    secureStorage.throwOnRead = true;

    final result = await storage.readSession();

    expect(result, isNull);
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNotNull,
    );
  });

  test('invalid legacy session returns null without crashing', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      '{not-json',
    );

    expect(await storage.readSession(), isNull);
  });

  test('corrupt secure session returns null and does not use legacy', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      _encode(_session(accessToken: 'stale-legacy')),
    );
    secureStorage.values[MobileAuthSessionStorage.secureSessionKey] =
        '{not-json';

    final result = await storage.readSession();

    expect(result, isNull);
    expect(
      secureStorage.values[MobileAuthSessionStorage.secureSessionKey],
      isNull,
    );
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNotNull,
    );
  });

  test('clearSession removes secure and legacy entries', () async {
    secureStorage.values[MobileAuthSessionStorage.secureSessionKey] =
        _encode(_session());
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      _encode(_session()),
    );

    await storage.clearSession();

    expect(
      secureStorage.values[MobileAuthSessionStorage.secureSessionKey],
      isNull,
    );
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNull,
    );
  });

  test('clearSession attempts legacy cleanup when secure cleanup fails',
      () async {
    secureStorage.throwOnDelete = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      MobileAuthSessionStorage.legacySessionKey,
      _encode(_session()),
    );

    await expectLater(storage.clearSession(), throwsA(isA<StateError>()));
    expect(
      preferences.getString(MobileAuthSessionStorage.legacySessionKey),
      isNull,
    );
  });
}

MobileAuthSession _session({String accessToken = 'access-token'}) {
  return MobileAuthSession(
    user: const MobileAuthUser(
      id: 'user-1',
      phone: '+77071234567',
      email: 'user@example.com',
    ),
    phone: '+77071234567',
    email: 'user@example.com',
    accessToken: accessToken,
    refreshToken: 'refresh-token',
    tokenType: 'bearer',
    accessExpiresAt: DateTime.parse('2026-09-14T01:00:00Z'),
    refreshExpiresAt: DateTime.parse('2026-10-14T01:00:00Z'),
    verifiedAt: DateTime.parse('2026-09-14T00:00:00Z'),
  );
}

String _encode(MobileAuthSession session) {
  return jsonEncode({
    'user': {
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

class InMemorySecureStorage implements SecureStorageAdapter {
  final Map<String, String> values = {};
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnDelete = false;

  @override
  Future<String?> read(String key) async {
    if (throwOnRead) {
      throw StateError('secure read failed');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (throwOnWrite) {
      throw StateError('secure write failed');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (throwOnDelete) {
      throw StateError('secure delete failed');
    }
    values.remove(key);
  }
}
