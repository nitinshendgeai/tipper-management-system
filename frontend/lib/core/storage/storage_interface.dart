/// Abstract interface for platform-specific key-value storage.
/// - Web implementation uses localStorage (storage_web.dart)
/// - Native implementation uses flutter_secure_storage (storage_native.dart)
abstract class StorageInterface {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}
