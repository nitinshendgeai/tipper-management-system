import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles secure persistence of the JWT authentication token.
/// Uses flutter_secure_storage (Keychain on iOS, Keystore on Android).
class TokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'tipper_auth_token';

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
}
