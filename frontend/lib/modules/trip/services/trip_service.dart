import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/trip_model.dart';

/// Phase 6 (FE-006): migrated from raw Dio() to DioClient.instance so the
/// shared 401 interceptor auto-redirects to login on token expiry.
class TripService {
  // ─── READ ──────────────────────────────────────────────────────────────────

  /// Fetches trips. Optional filters: status (CREATED/STARTED/COMPLETED/CANCELLED),
  /// vehicleId, driverId.
  Future<List<TripModel>> getTrips({
    String? status,
    int? vehicleId,
    int? driverId,
  }) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (vehicleId != null) params['vehicle_id'] = vehicleId;
    if (driverId != null) params['driver_id'] = driverId;

    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/trips/',
      queryParameters: params.isNotEmpty ? params : null,
      options: options,
    );

    final List data = response.data as List;
    return data
        .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get a single trip by ID.
  Future<TripModel> getTrip(int tripId) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/trips/$tripId',
      options: options,
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── CREATE ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createTrip(Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.post(
      '${ApiConstants.baseUrl}/trips/',
      data: payload,
      options: options,
    );
    return response.data as Map<String, dynamic>;
  }

  // ─── START ─────────────────────────────────────────────────────────────────

  Future<TripModel> startTrip(int tripId, double startKm) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.put(
      '${ApiConstants.baseUrl}/trips/$tripId/start',
      data: {'start_km': startKm},
      options: options,
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── COMPLETE ──────────────────────────────────────────────────────────────

  Future<TripModel> completeTrip(
    int tripId,
    Map<String, dynamic> payload,
  ) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.put(
      '${ApiConstants.baseUrl}/trips/$tripId/complete',
      data: payload,
      options: options,
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── CANCEL ────────────────────────────────────────────────────────────────

  Future<TripModel> cancelTrip(int tripId, {String? reason}) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.put(
      '${ApiConstants.baseUrl}/trips/$tripId/cancel',
      data: {'cancellation_reason': reason},
      options: options,
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }
}
