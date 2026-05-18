import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../models/route_model.dart';

class RouteService {
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

  // ─── READ ────────────────────────────────────────────────────────────────

  /// Fetches all active routes from the backend.
  Future<List<RouteModel>> getRoutes() async {
    final options = await _authOptions(); // Phase 3 fix: was missing auth token
    final response = await _dio.get(
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
    final options = await _authOptions();

    final response = await _dio.post(
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
    final options = await _authOptions();

    final response = await _dio.put(
      '${ApiConstants.baseUrl}/routes/$routeId',
      data: payload,
      options: options,
    );

    return RouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────

  /// Soft-deletes a route by ID. Requires admin JWT token.
  Future<void> deleteRoute(int routeId) async {
    final options = await _authOptions();

    await _dio.delete(
      '${ApiConstants.baseUrl}/routes/$routeId',
      options: options,
    );
  }
}
