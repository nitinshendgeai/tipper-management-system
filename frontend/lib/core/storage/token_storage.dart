import 'storage_interface.dart';
import 'storage_native.dart'
    if (dart.library.html) 'storage_web.dart';

/// Handles secure persistence of the JWT authentication token, role, and user info.
///
/// Uses conditional imports — the correct implementation is selected at
/// compile time, never at runtime:
///   - Web build   → storage_web.dart    (localStorage, no dart:html on native)
///   - Native build → storage_native.dart (flutter_secure_storage)
class TokenStorage {
  static final StorageInterface _store = getStorage();

  static const String _tokenKey = 'tipper_auth_token';
  static const String _roleKey  = 'tipper_auth_role';
  static const String _nameKey  = 'tipper_auth_name';
  static const String _emailKey = 'tipper_auth_email';

  static Future<void> saveToken(String token) =>
      _store.write(_tokenKey, token);

  static Future<String?> getToken() => _store.read(_tokenKey);

  static Future<bool> hasToken() async {
    final token = await _store.read(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearToken() => _store.delete(_tokenKey);

  static Future<void> saveRole(String roleName) =>
      _store.write(_roleKey, roleName);

  static Future<String?> getRole() => _store.read(_roleKey);

  static Future<void> clearRole() => _store.delete(_roleKey);

  static Future<void> saveName(String name) => _store.write(_nameKey, name);

  static Future<String?> getName() => _store.read(_nameKey);

  static Future<void> saveEmail(String email) =>
      _store.write(_emailKey, email);

  static Future<String?> getEmail() => _store.read(_emailKey);

  static Future<void> clearAll() async {
    await _store.delete(_tokenKey);
    await _store.delete(_roleKey);
    await _store.delete(_nameKey);
    await _store.delete(_emailKey);
  }
}
