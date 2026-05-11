import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../models/vehicle_model.dart';

class VehicleService {

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

  // ─── READ ────────────────────────────────────────────────────────────────────

  /// Fetches all active vehicles from the backend.
  Future<List<VehicleModel>> getVehicles() async {

    final response = await _dio.get(
      '${ApiConstants.baseUrl}/vehicles/',
    );

    final List data = response.data as List;

    return data
        .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── CREATE ──────────────────────────────────────────────────────────────────

  /// Creates a new vehicle. Requires admin JWT token.
  Future<VehicleModel> createVehicle(Map<String, dynamic> payload) async {

    final options = await _authOptions();

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/vehicles/',
      data: payload,
      options: options,
    );

    return VehicleModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── UPDATE ──────────────────────────────────────────────────────────────────

  /// Updates an existing vehicle by ID. Requires admin JWT token.
  Future<VehicleModel> updateVehicle(
    int vehicleId,
    Map<String, dynamic> payload,
  ) async {

    final options = await _authOptions();

    final response = await _dio.put(
      '${ApiConstants.baseUrl}/vehicles/$vehicleId',
      data: payload,
      options: options,
    );

    return VehicleModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────────

  /// Soft-deletes a vehicle by ID. Requires admin JWT token.
  Future<void> deleteVehicle(int vehicleId) async {

    final options = await _authOptions();

    await _dio.delete(
      '${ApiConstants.baseUrl}/vehicles/$vehicleId',
      options: options,
    );
  }
}
