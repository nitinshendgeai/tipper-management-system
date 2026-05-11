import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../models/assignment_model.dart';

class AllocationService {

  final Dio _dio = Dio();

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getToken();
    return Options(headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
  }

  // ─── List active assignments ─────────────────────────────────────────────

  Future<List<AssignmentModel>> getActiveAssignments() async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/allocations/active',
    );
    final List data = response.data as List;
    return data.map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── List all assignments (history) ─────────────────────────────────────

  Future<List<AssignmentModel>> getAllAssignments() async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/allocations/',
    );
    final List data = response.data as List;
    return data.map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Get vehicle assignment status ──────────────────────────────────────

  Future<VehicleAssignmentStatus> getVehicleStatus(int vehicleId) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/allocations/vehicle/$vehicleId/status',
    );
    return VehicleAssignmentStatus.fromJson(
        response.data as Map<String, dynamic>);
  }

  // ─── Create assignment ───────────────────────────────────────────────────

  Future<AssignmentModel> createAssignment(Map<String, dynamic> payload) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/allocations/',
      data: payload,
      options: options,
    );
    return AssignmentModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Release assignment ──────────────────────────────────────────────────

  Future<AssignmentModel> releaseAssignment(int assignmentId, {String? remarks}) async {
    final options = await _authOptions();
    final response = await _dio.put(
      '${ApiConstants.baseUrl}/allocations/$assignmentId/release',
      data: {'remarks': remarks},
      options: options,
    );
    return AssignmentModel.fromJson(response.data as Map<String, dynamic>);
  }
}
