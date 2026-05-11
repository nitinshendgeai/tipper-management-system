import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';

class AuthService {
  final Dio dio = Dio();

  /// Authenticates the user and persists the JWT token on success.
  /// Returns the token string if successful, null otherwise.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '${ApiConstants.baseUrl}/auth/login',

        data: {"email": email, "password": password},
      );

      final token = response.data['access_token'] as String?;

      if (token != null && token.isNotEmpty) {
        await TokenStorage.saveToken(token);
      }

      return token;
    } catch (e) {
      // Intentionally swallow details here; the UI shows a generic auth error.
      return null;
    }
  }

  /// Clears the stored token and logs the user out.
  Future<void> logout() async {
    await TokenStorage.clearToken();
  }
}
