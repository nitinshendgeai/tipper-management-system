import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

/// Service for the /users/ API — Phase 11 User Management.
class UserService {
  Future<List<Map<String, dynamic>>> getUsers() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/users/',
      options: options,
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.post(
      '${ApiConstants.baseUrl}/users/',
      data: payload,
      options: options,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUser(
      int id, Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.patch(
      '${ApiConstants.baseUrl}/users/$id',
      data: payload,
      options: options,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deactivateUser(int id) async {
    final options = await DioClient.authOptions();
    await DioClient.instance.delete(
      '${ApiConstants.baseUrl}/users/$id',
      options: options,
    );
  }
}
