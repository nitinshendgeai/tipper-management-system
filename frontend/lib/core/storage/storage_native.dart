import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage_interface.dart';

/// Native storage implementation — uses flutter_secure_storage.
/// Keychain on iOS, Keystore on Android, credential store on desktop.
class PlatformStorage implements StorageInterface {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Returns the native storage instance.
StorageInterface getStorage() => PlatformStorage();
