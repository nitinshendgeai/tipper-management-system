import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

class FuelService {
  Future<List<Map<String, dynamic>>> getFuelLogs() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/fuel/',
      options: options,
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createLog(Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.post(
      '${ApiConstants.baseUrl}/fuel/',
      data: payload,
      options: options,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteLog(int id) async {
    final options = await DioClient.authOptions();
    await DioClient.instance.delete(
      '${ApiConstants.baseUrl}/fuel/$id',
      options: options,
    );
  }
}
