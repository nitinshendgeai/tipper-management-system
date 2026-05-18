import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles secure persistence of the JWT authentication token and role.
/// Uses flutter_secure_storage (Keychain on iOS, Keystore on Android).
class TokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'tipper_auth_token';
  static const String _roleKey  = 'tipper_auth_role'; // Phase 3 addition

  // ─── Token ────────────────────────────────────────────────────────────────

  /// Saves the JWT token securely.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Retrieves the stored JWT token, or null if none exists.
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Checks whether a token is currently stored.
  static Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Clears the stored token (use on logout).
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ─── Role (Phase 3) ───────────────────────────────────────────────────────

  /// Saves the user's role_name from the JWT payload (e.g. 'MANAGER').
  static Future<void> saveRole(String roleName) async {
    await _storage.write(key: _roleKey, value: roleName);
  }

  /// Retrieves the stored role name, or null if not set.
  static Future<String?> getRole() async {
    return await _storage.read(key: _roleKey);
  }

  /// Clears the stored role (use on logout).
  static Future<void> clearRole() async {
    await _storage.delete(key: _roleKey);
  }

  // ─── Combined ─────────────────────────────────────────────────────────────

  /// Clears both token and role — call on logout.
  static Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
  }
}
