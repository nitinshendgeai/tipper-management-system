import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _secure = FlutterSecureStorage();
  static const _tokenKey = 'tipper_auth_token';
  static const _roleKey = 'tipper_auth_role';
  static const _nameKey = 'tipper_auth_name';
  static const _emailKey = 'tipper_auth_email';

  static Future<void> _write(String key, String value) async {
    await _secure.write(key: key, value: value);
  }

  static Future<String?> _read(String key) async {
    return await _secure.read(key: key);
  }

  static Future<void> _delete(String key) async {
    await _secure.delete(key: key);
  }

  static Future<void> saveToken(String t) => _write(_tokenKey, t);
  static Future<String?> getToken() => _read(_tokenKey);
  static Future<bool> hasToken() async {
    final t = await _read(_tokenKey);
    return t != null && t.isNotEmpty;
  }
  static Future<void> clearToken() => _delete(_tokenKey);
  static Future<void> saveRole(String r) => _write(_roleKey, r);
  static Future<String?> getRole() => _read(_roleKey);
  static Future<void> clearRole() => _delete(_roleKey);
  static Future<void> saveName(String n) => _write(_nameKey, n);
  static Future<String?> getName() => _read(_nameKey);
  static Future<void> saveEmail(String e) => _write(_emailKey, e);
  static Future<String?> getEmail() => _read(_emailKey);
  static Future<void> clearAll() async {
    await _delete(_tokenKey);
    await _delete(_roleKey);
    await _delete(_nameKey);
    await _delete(_emailKey);
  }
}
