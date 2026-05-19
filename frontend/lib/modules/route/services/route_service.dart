import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/route_model.dart';

/// Phase 6 (FE-006): migrated from raw Dio() to DioClient.instance.
class RouteService {
  // ─── READ ────────────────────────────────────────────────────────────────

  /// Fetches all active routes from the backend.
  Future<List<RouteModel>> getRoutes() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/routes/',
      options: options,
    );

    final List data = response.data as List;

    return data
        .map((e) => RouteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── CREATE ──────────────────────────────────────────────────────────────

  /// Creates a new route. Requires admin JWT token.
  Future<RouteModel> createRoute(Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();

    final response = await DioClient.instance.post(
      '${ApiConstants.baseUrl}/routes/',
      data: payload,
      options: options,
    );

    return RouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── UPDATE ──────────────────────────────────────────────────────────────

  /// Updates an existing route by ID. Requires admin JWT token.
  Future<RouteModel> updateRoute(
    int routeId,
    Map<String, dynamic> payload,
  ) async {
    final options = await DioClient.authOptions();

    final response = await DioClient.instance.put(
      '${ApiConstants.baseUrl}/routes/$routeId',
      data: payload,
      options: options,
    );

    return RouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────

  /// Soft-deletes a route by ID. Requires admin JWT token.
  Future<void> deleteRoute(int routeId) async {
    final options = await DioClient.authOptions();

    await DioClient.instance.delete(
      '${ApiConstants.baseUrl}/routes/$routeId',
      options: options,
    );
  }
}
