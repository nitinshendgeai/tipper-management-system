/// Attendance model — mirrors the backend AttendanceResponse schema.

class AttendanceModel {
  final int id;
  final int driverId;
  final String driverName;
  final DateTime shiftDate;
  final DateTime? punchIn;
  final DateTime? punchOut;
  final String status; // PRESENT | ABSENT
  final bool isActive;  // true = currently on duty
  final DateTime createdAt;

  const AttendanceModel({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.shiftDate,
    this.punchIn,
    this.punchOut,
    required this.status,
    required this.isActive,
    required this.createdAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as int,
      driverId: json['driver_id'] as int,
      driverName: json['driver_name'] as String? ?? 'Unknown',
      shiftDate: DateTime.parse(json['shift_date'] as String),
      punchIn: json['punch_in'] != null
          ? DateTime.parse(json['punch_in'] as String)
          : null,
      punchOut: json['punch_out'] != null
          ? DateTime.parse(json['punch_out'] as String)
          : null,
      status: json['status'] as String? ?? 'PRESENT',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isOnDuty => isActive && punchIn != null && punchOut == null;

  /// Duration of the shift so far (or full duration if punched out).
  Duration? get shiftDuration {
    if (punchIn == null) return null;
    final end = punchOut ?? DateTime.now();
    return end.difference(punchIn!);
  }

  String get shiftDurationLabel {
    final d = shiftDuration;
    if (d == null) return '--';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }
}
