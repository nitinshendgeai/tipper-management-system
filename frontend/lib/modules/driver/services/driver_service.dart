import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../models/driver_model.dart';

class DriverService {
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

  /// Fetches all active drivers from the backend.
  Future<List<DriverModel>> getDrivers() async {
    final response = await _dio.get('${ApiConstants.baseUrl}/drivers/');

    final List data = response.data as List;

    return data
        .map((e) => DriverModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── CREATE ──────────────────────────────────────────────────────────────

  /// Creates a new driver. Requires admin JWT token.
  Future<DriverModel> createDriver(Map<String, dynamic> payload) async {
    final options = await _authOptions();

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/drivers/',
      data: payload,
      options: options,
    );

    return DriverModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── UPDATE ──────────────────────────────────────────────────────────────

  /// Updates an existing driver by ID. Requires admin JWT token.
  Future<DriverModel> updateDriver(
    int driverId,
    Map<String, dynamic> payload,
  ) async {
    final options = await _authOptions();

    final response = await _dio.put(
      '${ApiConstants.baseUrl}/drivers/$driverId',
      data: payload,
      options: options,
    );

    return DriverModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────

  /// Soft-deletes a driver by ID. Requires admin JWT token.
  Future<void> deleteDriver(int driverId) async {
    final options = await _authOptions();

    await _dio.delete(
      '${ApiConstants.baseUrl}/drivers/$driverId',
      options: options,
    );
  }
}
