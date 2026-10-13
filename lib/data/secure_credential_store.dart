import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-backed storage for optional AI credentials.
///
/// The learning core never needs this store. Callers can catch plugin errors
/// on unsupported test hosts and use a non-secret empty value instead.
abstract interface class CredentialStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterCredentialStore implements CredentialStore {
  final FlutterSecureStorage _storage;

  FlutterCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
