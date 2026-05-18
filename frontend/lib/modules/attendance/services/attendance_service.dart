import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final Dio _dio = Dio();

  /// Builds Dio options with the stored Bearer token.
  Future<Options> _authOptions() async {
    final token = await TokenStorage.getToken();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  // ─── PUNCH IN ────────────────────────────────────────────────────────────────

  /// Mark driver as PRESENT.
  /// [driverId] — required for SUPERVISOR/MANAGER; omit for DRIVER (auto-resolved
  /// if user_id is linked, otherwise pass own driver ID).
  Future<AttendanceModel> punchIn({int? driverId}) async {
    final options = await _authOptions();
    final body = driverId != null ? {'driver_id': driverId} : <String, dynamic>{};

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/attendance/punch-in',
      data: body,
      options: options,
    );

    return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── PUNCH OUT ───────────────────────────────────────────────────────────────

  /// End driver shift.
  /// [driverId] — required for SUPERVISOR/MANAGER; omit for DRIVER.
  Future<AttendanceModel> punchOut({int? driverId}) async {
    final options = await _authOptions();
    final body = driverId != null ? {'driver_id': driverId} : <String, dynamic>{};

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/attendance/punch-out',
      data: body,
      options: options,
    );

    return AttendanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── TODAY'S ATTENDANCE ───────────────────────────────────────────────────────

  /// Fetch today's attendance records (SUPERVISOR+ sees all; DRIVER sees own).
  Future<List<AttendanceModel>> getTodayAttendance() async {
    final options = await _authOptions();

    final response = await _dio.get(
      '${ApiConstants.baseUrl}/attendance/today',
      options: options,
    );

    final List data = response.data as List;
    return data
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── OWN ATTENDANCE (DRIVER) ──────────────────────────────────────────────────

  /// Fetch own attendance history — DRIVER role only.
  Future<List<AttendanceModel>> getMyAttendance() async {
    final options = await _authOptions();

    final response = await _dio.get(
      '${ApiConstants.baseUrl}/attendance/me',
      options: options,
    );

    final List data = response.data as List;
    return data
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── FULL HISTORY (MANAGER+) ──────────────────────────────────────────────────

  /// Fetch full attendance history.
  /// [shiftDate] — optional filter: 'YYYY-MM-DD'.
  /// [driverId] — optional filter by driver.
  Future<List<AttendanceModel>> getAttendance({
    String? shiftDate,
    int? driverId,
  }) async {
    final options = await _authOptions();

    final queryParams = <String, dynamic>{};
    if (shiftDate != null) queryParams['shift_date'] = shiftDate;
    if (driverId != null) queryParams['driver_id'] = driverId;

    final response = await _dio.get(
      '${ApiConstants.baseUrl}/attendance/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      options: options,
    );

    final List data = response.data as List;
    return data
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
