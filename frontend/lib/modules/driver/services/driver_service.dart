import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/driver_model.dart';

/// Phase 6 (FE-006): migrated from raw Dio() to DioClient.instance.
class DriverService {
  // ─── READ ────────────────────────────────────────────────────────────────

  /// Fetches all active drivers from the backend.
  Future<List<DriverModel>> getDrivers() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/drivers/',
      options: options,
    );

    final List data = response.data as List;

    return data
        .map((e) => DriverModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── CREATE ──────────────────────────────────────────────────────────────

  /// Creates a new driver. Requires admin JWT token.
  Future<DriverModel> createDriver(Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();

    final response = await DioClient.instance.post(
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
    final options = await DioClient.authOptions();

    final response = await DioClient.instance.put(
      '${ApiConstants.baseUrl}/drivers/$driverId',
      data: payload,
      options: options,
    );

    return DriverModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────

  /// Soft-deletes a driver by ID. Requires admin JWT token.
  Future<void> deleteDriver(int driverId) async {
    final options = await DioClient.authOptions();

    await DioClient.instance.delete(
      '${ApiConstants.baseUrl}/drivers/$driverId',
      options: options,
    );
  }
}
