import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../models/trip_model.dart';

class TripService {
  final Dio _dio = Dio();

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getToken();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

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

    final options = await _authOptions(); // Phase 3 fix: was missing auth token
    final response = await _dio.get(
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
    final options = await _authOptions(); // Phase 3 fix: was missing auth token
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/trips/$tripId',
      options: options,
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── CREATE ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createTrip(Map<String, dynamic> payload) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/trips/',
      data: payload,
      options: options,
    );
    return response.data as Map<String, dynamic>;
  }

  // ─── START ─────────────────────────────────────────────────────────────────

  Future<TripModel> startTrip(int tripId, double startKm) async {
    final options = await _authOptions();
    final response = await _dio.put(
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
    final options = await _authOptions();
    final response = await _dio.put(
      '${ApiConstants.baseUrl}/trips/$tripId/complete',
      data: payload,
      options: options,
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── CANCEL ────────────────────────────────────────────────────────────────

  Future<TripModel> cancelTrip(int tripId, {String? reason}) async {
    final options = await _authOptions();
    final response = await _dio.put(
      '${ApiConstants.baseUrl}/trips/$tripId/cancel',
      data: {'cancellation_reason': reason},
      options: options,
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }
}
