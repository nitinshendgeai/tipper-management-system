import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthService {
  /// Authenticates the user and persists the JWT token on success.
  /// Returns a map with 'token' and 'must_change_password', or null on failure.
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
    String? companyName,
  }) async {
    final Map<String, dynamic> payload = {
      "email": email,
      "password": password,
    };
    if (companyName != null && companyName.trim().isNotEmpty) {
      payload["company_slug"] = companyName.trim();
    }

    try {
      final response = await DioClient.instance.post(
        '${ApiConstants.baseUrl}/auth/login',
        data: payload,
      );

      final token = response.data['access_token'] as String?;
      final mustChange = response.data['must_change_password'] as bool? ?? false;

      if (token != null && token.isNotEmpty) {
        await TokenStorage.saveToken(token);

        // Decode JWT and persist role + email
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final normalized = base64Url.normalize(parts[1]);
            final decoded = utf8.decode(base64Url.decode(normalized));
            final claims = jsonDecode(decoded) as Map<String, dynamic>;

            final roleName = claims['role_name'] as String?;
            if (roleName != null && roleName.isNotEmpty) {
              await TokenStorage.saveRole(roleName);
            }

            final emailFromJwt = claims['sub'] as String?;
            if (emailFromJwt != null && emailFromJwt.isNotEmpty) {
              await TokenStorage.saveEmail(emailFromJwt);
            }
          }
        } catch (e) {
          // Non-fatal
        }

        // Fetch full name from /auth/me
        try {
          final meResp = await DioClient.instance.get(
            '${ApiConstants.baseUrl}/auth/me',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          final fullName = meResp.data['full_name'] as String?;
          if (fullName != null && fullName.isNotEmpty) {
            await TokenStorage.saveName(fullName);
          }
        } catch (e) {
          // Non-fatal
        }

        return {'token': token, 'must_change_password': mustChange};
      }
      return null;
    } on DioException catch (e) {
      // Return null so UI shows error message
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clears the stored token and role, logging the user out.
  Future<void> logout() async {
    await TokenStorage.clearAll();
  }
}
