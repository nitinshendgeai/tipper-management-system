import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../models/dashboard_stats_model.dart';

class DashboardService {
  final Dio _dio = Dio();

  /// Fetches live counts for vehicles, drivers, routes, and trips.
  /// Endpoint: GET /dashboard/stats (public — no auth required).
  Future<DashboardStatsModel> getStats() async {
    final response = await _dio.get('${ApiConstants.baseUrl}/dashboard/stats');

    return DashboardStatsModel.fromJson(response.data as Map<String, dynamic>);
  }
}
