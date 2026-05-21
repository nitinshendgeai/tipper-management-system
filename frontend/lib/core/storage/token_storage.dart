// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles secure persistence of the JWT token, role, and user info.
/// Web: uses browser localStorage directly (dart:html).
/// Native: uses flutter_secure_storage.
class TokenStorage {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _tokenKey = 'tipper_auth_token';
  static const String _roleKey  = 'tipper_auth_role';
  static const String _nameKey  = 'tipper_auth_name';
  static const String _emailKey = 'tipper_auth_email';

  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      html.window.localStorage[key] = value;
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      final val = html.window.localStorage[key];
      return (val == null || val.isEmpty) ? null : val;
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  static Future<void> _delete(String key) async {
    if (kIsWeb) {
      html.window.localStorage.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  static Future<void> saveToken(String token) => _write(_tokenKey, token);
  static Future<String?> getToken() => _read(_tokenKey);
  static Future<bool> hasToken() async {
    final t = await _read(_tokenKey);
    return t != null && t.isNotEmpty;
  }
  static Future<void> clearToken() => _delete(_tokenKey);

  static Future<void> saveRole(String role) => _write(_roleKey, role);
  static Future<String?> getRole() => _read(_roleKey);
  static Future<void> clearRole() => _delete(_roleKey);

  static Future<void> saveName(String name) => _write(_nameKey, name);
  static Future<String?> getName() => _read(_nameKey);

  static Future<void> saveEmail(String email) => _write(_emailKey, email);
  static Future<String?> getEmail() => _read(_emailKey);

  static Future<void> clearAll() async {
    await _delete(_tokenKey);
    await _delete(_roleKey);
    await _delete(_nameKey);
    await _delete(_emailKey);
  }
}
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
