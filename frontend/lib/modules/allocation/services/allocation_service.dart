import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/assignment_model.dart';

/// Phase 6 (FE-006): migrated from raw Dio() to DioClient.instance.
class AllocationService {
  // ─── List active assignments ─────────────────────────────────────────────

  Future<List<AssignmentModel>> getActiveAssignments() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/allocations/active',
      options: options,
    );
    final List data = response.data as List;
    return data
        .map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── List all assignments (history) ─────────────────────────────────────

  Future<List<AssignmentModel>> getAllAssignments() async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/allocations/',
      options: options,
    );
    final List data = response.data as List;
    return data
        .map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Get vehicle assignment status ──────────────────────────────────────

  Future<VehicleAssignmentStatus> getVehicleStatus(int vehicleId) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/allocations/vehicle/$vehicleId/status',
      options: options,
    );
    return VehicleAssignmentStatus.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ─── Create assignment ───────────────────────────────────────────────────

  Future<AssignmentModel> createAssignment(Map<String, dynamic> payload) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.post(
      '${ApiConstants.baseUrl}/allocations/',
      data: payload,
      options: options,
    );
    return AssignmentModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Release assignment ──────────────────────────────────────────────────

  Future<AssignmentModel> releaseAssignment(
    int assignmentId, {
    String? remarks,
  }) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.put(
      '${ApiConstants.baseUrl}/allocations/$assignmentId/release',
      data: {'remarks': remarks},
      options: options,
    );
    return AssignmentModel.fromJson(response.data as Map<String, dynamic>);
  }
}
