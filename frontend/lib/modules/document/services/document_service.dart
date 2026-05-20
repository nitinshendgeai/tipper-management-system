import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

class DocumentService {
  Future<List<Map<String, dynamic>>> getDocuments() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/documents/',
      options: options,
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createDocument(
      Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.post(
      '${ApiConstants.baseUrl}/documents/',
      data: payload,
      options: options,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteDocument(int id) async {
    final options = await DioClient.authOptions();
    await DioClient.instance.delete(
      '${ApiConstants.baseUrl}/documents/$id',
      options: options,
    );
  }
}
