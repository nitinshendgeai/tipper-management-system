import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
// Deferred import to avoid circular dependency — only used inside interceptor.
// ignore: directives_ordering
import '../../modules/auth/screens/login_screen.dart';

/// Shared Dio client with:
///   - Base URL configured from ApiConstants
///   - 401 interceptor: clears credentials and navigates to login on token expiry
///
/// Phase 4: Added to handle expired JWT tokens across the entire app.
/// All services should use [DioClient.instance] instead of creating
/// individual Dio() objects.
///
/// Usage:
///   final response = await DioClient.instance.get('/vehicles/', options: await DioClient.authOptions());
class DioClient {
  DioClient._();

  static final Dio _dio = _createDio();

  /// The shared Dio instance. Configure once; use everywhere.
  static Dio get instance => _dio;

  /// Nullable global navigator key — set once in main.dart / MaterialApp.
  /// Required by the 401 interceptor to navigate without a BuildContext.
  static GlobalKey<NavigatorState>? navigatorKey;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );

    dio.interceptors.add(_AuthInterceptor());

    return dio;
  }

  /// Build Dio request options with the current Bearer token.
  static Future<Options> authOptions() async {
    final token = await TokenStorage.getToken();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }
}

/// Intercepts 401 responses: clears stored credentials and redirects to login.
///
/// Phase 4 — FE-004: This addresses the known gap where expired tokens caused
/// silent failures on all authenticated endpoints. Users are now redirected to
/// the login screen when their session expires.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Automatically inject Bearer token on every request
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await TokenStorage.clearAll();
      final nav = DioClient.navigatorKey?.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
    handler.next(err);
  }
}
