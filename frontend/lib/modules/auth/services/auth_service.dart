import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';

class AuthService {
  final Dio dio = Dio();

  /// Authenticates the user and returns the token string, or null on failure.
  Future<String?> login({
    required String email,
    required String password,
    String? companyName,
  }) async {
    final Map<String, dynamic> payload = {
      "email": email,
      "password": password,
    };

    try {
      final response = await dio.post(
        '${ApiConstants.baseUrl}/auth/login',
        data: payload,
      );

      final token = response.data['access_token'] as String?;

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
            if (roleName != null) await TokenStorage.saveRole(roleName);

            final emailJwt = claims['sub'] as String?;
            if (emailJwt != null) await TokenStorage.saveEmail(emailJwt);
          }
        } catch (_) {}

        // Fetch full name
        try {
          final meResp = await dio.get(
            '${ApiConstants.baseUrl}/auth/me',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          final fullName = meResp.data['full_name'] as String?;
          if (fullName != null) await TokenStorage.saveName(fullName);
        } catch (_) {}
      }

      return token;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    await TokenStorage.clearAll();
  }
}
