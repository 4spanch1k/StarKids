import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small seam around platform-backed secure storage for testable persistence.
abstract interface class SecureStorageAdapter {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureStorageAdapter implements SecureStorageAdapter {
  FlutterSecureStorageAdapter({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
