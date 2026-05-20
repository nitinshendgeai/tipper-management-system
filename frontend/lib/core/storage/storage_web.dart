// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'storage_interface.dart';

/// Web storage implementation — uses browser localStorage.
/// Works on all browsers including mobile Safari and Android Chrome.
/// This file is ONLY compiled on web — never imported on native targets.
class PlatformStorage implements StorageInterface {
  @override
  Future<void> write(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return html.window.localStorage[key];
  }

  @override
  Future<void> delete(String key) async {
    html.window.localStorage.remove(key);
  }
}

/// Returns the web storage instance.
StorageInterface getStorage() => PlatformStorage();
