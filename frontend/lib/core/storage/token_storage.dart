import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Handles secure persistence of the JWT authentication token, role, and user info.
/// - Web: uses browser localStorage directly (works on all mobile/desktop browsers)
/// - Native: uses flutter_secure_storage (Keychain on iOS, Keystore on Android)
class TokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'tipper_auth_token';
  static const String _roleKey  = 'tipper_auth_role';
  static const String _nameKey  = 'tipper_auth_name';
  static const String _emailKey = 'tipper_auth_email';

  // ─── Internal web helpers ─────────────────────────────────────────────────

  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      html.window.localStorage[key] = value;
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      return html.window.localStorage[key];
    } else {
      return await _storage.read(key: key);
    }
  }

  static Future<void> _delete(String key) async {
    if (kIsWeb) {
      html.window.localStorage.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  // ─── Token ────────────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async =>
      _write(_tokenKey, token);

  static Future<String?> getToken() async => _read(_tokenKey);

  static Future<bool> hasToken() async {
    final token = await _read(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearToken() async => _delete(_tokenKey);

  // ─── Role ─────────────────────────────────────────────────────────────────

  static Future<void> saveRole(String roleName) async =>
      _write(_roleKey, roleName);

  static Future<String?> getRole() async => _read(_roleKey);

  static Future<void> clearRole() async => _delete(_roleKey);

  // ─── Name ─────────────────────────────────────────────────────────────────

  static Future<void> saveName(String name) async => _write(_nameKey, name);

  static Future<String?> getName() async => _read(_nameKey);

  // ─── Email ────────────────────────────────────────────────────────────────

  static Future<void> saveEmail(String email) async =>
      _write(_emailKey, email);

  static Future<String?> getEmail() async => _read(_emailKey);

  // ─── Combined ─────────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    await _delete(_tokenKey);
    await _delete(_roleKey);
    await _delete(_nameKey);
    await _delete(_emailKey);
  }
}
