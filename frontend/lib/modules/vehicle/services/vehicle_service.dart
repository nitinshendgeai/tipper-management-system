import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/vehicle_model.dart';

/// Phase 6 (FE-006): migrated from raw Dio() to DioClient.instance.
class VehicleService {
  // ─── READ ────────────────────────────────────────────────────────────────────

  /// Fetches all active vehicles from the backend.
  Future<List<VehicleModel>> getVehicles() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/vehicles/',
      options: options,
    );

    final List data = response.data as List;

    return data
        .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── CREATE ──────────────────────────────────────────────────────────────────

  /// Creates a new vehicle. Requires admin JWT token.
  Future<VehicleModel> createVehicle(Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();

    final response = await DioClient.instance.post(
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
    final options = await DioClient.authOptions();

    final response = await DioClient.instance.put(
      '${ApiConstants.baseUrl}/vehicles/$vehicleId',
      data: payload,
      options: options,
    );

    return VehicleModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────────

  /// Soft-deletes a vehicle by ID. Requires admin JWT token.
  Future<void> deleteVehicle(int vehicleId) async {
    final options = await DioClient.authOptions();

    await DioClient.instance.delete(
      '${ApiConstants.baseUrl}/vehicles/$vehicleId',
      options: options,
    );
  }
}
