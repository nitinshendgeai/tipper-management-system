import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart'; // Phase 3 fix: import for auth
import '../models/dashboard_stats_model.dart';

class DashboardService {
  final Dio _dio = Dio();

  /// Builds Dio request options with the stored Bearer token.
  Future<Options> _authOptions() async {
    final token = await TokenStorage.getToken();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  /// Fetches live counts for vehicles, drivers, routes, and trips.
  /// Endpoint: GET /dashboard/stats — requires auth (tenant-scoped).
  Future<DashboardStatsModel> getStats() async {
    final options = await _authOptions(); // Phase 3 fix: was missing auth token
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/dashboard/stats',
      options: options,
    );

    return DashboardStatsModel.fromJson(response.data as Map<String, dynamic>);
  }
}
