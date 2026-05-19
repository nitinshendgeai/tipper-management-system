import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/dashboard_stats_model.dart';

/// Phase 6 (FE-006): migrated from raw Dio() to DioClient.instance.
class DashboardService {
  /// Fetches live counts for vehicles, drivers, routes, and trips.
  /// Endpoint: GET /dashboard/stats — requires auth (tenant-scoped).
  Future<DashboardStatsModel> getStats() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/dashboard/stats',
      options: options,
    );

    return DashboardStatsModel.fromJson(response.data as Map<String, dynamic>);
  }
}
