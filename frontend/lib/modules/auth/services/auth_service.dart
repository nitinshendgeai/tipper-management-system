import 'dart:convert';

import 'package:dio/dio.dart';
// Options is re-exported from package:dio/dio.dart — no extra import needed

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';

class AuthService {
  final Dio dio = Dio();

  /// Authenticates the user and persists the JWT token on success.
  /// Returns the token string if successful, null otherwise.
  ///
  /// Phase 6 (AUTH-001): added optional [companyName] parameter.
  /// When provided, login is scoped to that specific company — preventing
  /// cross-tenant auth in multi-tenant mode. Safe to omit for backward compat.
  Future<String?> login({
    required String email,
    required String password,
    String? companyName,
  }) async {
    print('[AuthService] login() called with email: $email');
    print('[AuthService] POST ${ApiConstants.baseUrl}/auth/login');

    final Map<String, dynamic> payload = {
      "email": email,
      "password": password,
    };
    if (companyName != null && companyName.trim().isNotEmpty) {
      payload["company_slug"] = companyName.trim();
    }

    try {
      final response = await dio.post(
        '${ApiConstants.baseUrl}/auth/login',
        data: payload,
      );

      print('[AuthService] Response status: ${response.statusCode}');
      print('[AuthService] Response body: ${response.data}');

      final token = response.data['access_token'] as String?;

      if (token != null && token.isNotEmpty) {
        print('[AuthService] Token received, saving to storage.');
        await TokenStorage.saveToken(token);

        // Phase 3: decode JWT payload and persist role_name for RBAC UI
        // Phase 8: also persist email (from sub claim) for dashboard header
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final normalized = base64Url.normalize(parts[1]);
            final decoded = utf8.decode(base64Url.decode(normalized));
            final claims = jsonDecode(decoded) as Map<String, dynamic>;

            final roleName = claims['role_name'] as String?;
            if (roleName != null && roleName.isNotEmpty) {
              await TokenStorage.saveRole(roleName);
              print('[AuthService] Role saved: $roleName');
            }

            final emailFromJwt = claims['sub'] as String?;
            if (emailFromJwt != null && emailFromJwt.isNotEmpty) {
              await TokenStorage.saveEmail(emailFromJwt);
            }
          }
        } catch (e) {
          print('[AuthService] WARNING: Could not decode JWT: $e');
        }

        // Phase 8: fetch /auth/me to persist full_name for dashboard header
        try {
          final meResp = await dio.get(
            '${ApiConstants.baseUrl}/auth/me',
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
            ),
          );
          final fullName = meResp.data['full_name'] as String?;
          if (fullName != null && fullName.isNotEmpty) {
            await TokenStorage.saveName(fullName);
            print('[AuthService] User name saved: $fullName');
          }
        } catch (e) {
          print('[AuthService] WARNING: Could not fetch /auth/me: $e');
          // Non-fatal — dashboard header will fall back to email
        }
      } else {
        print('[AuthService] WARNING: Response succeeded but no access_token found in body.');
      }

      return token;
    } on DioException catch (e) {
      print('[AuthService] DioException during login:');
      print('  Type    : ${e.type}');
      print('  Message : ${e.message}');
      if (e.response != null) {
        print('  Status  : ${e.response!.statusCode}');
        print('  Body    : ${e.response!.data}');
      } else {
        print('  No response received (network/timeout issue).');
      }
      // Keep null return so the UI can show a generic auth error.
      return null;
    } catch (e, stackTrace) {
      print('[AuthService] Unexpected error during login: $e');
      print('[AuthService] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Clears the stored token and role, logging the user out.
  Future<void> logout() async {
    await TokenStorage.clearAll(); // Phase 3 fix: also clears role
  }
}
