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
    print('[AuthService] login() called with email: $email');
    print('[AuthService] POST ${ApiConstants.baseUrl}/auth/login');

    try {
      final response = await dio.post(
        '${ApiConstants.baseUrl}/auth/login',
        data: {"email": email, "password": password},
      );

      print('[AuthService] Response status: ${response.statusCode}');
      print('[AuthService] Response body: ${response.data}');

      final token = response.data['access_token'] as String?;

      if (token != null && token.isNotEmpty) {
        print('[AuthService] Token received, saving to storage.');
        await TokenStorage.saveToken(token);
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

  /// Clears the stored token and logs the user out.
  Future<void> logout() async {
    await TokenStorage.clearToken();
  }
}
