class AssignmentModel {

  final int id;

  final int vehicleId;
  final String vehicleNumber;
  final String? vehicleType;
  final String vehicleStatus;

  final int driverId;
  final String driverName;
  final String driverMobile;
  final String driverStatus;

  final int? assignedBy;
  final String? assignedByName;
  final DateTime? assignedAt;
  final DateTime? shiftDate;
  final DateTime? releasedAt;
  final String? remarks;
  final bool isActive;

  const AssignmentModel({
    required this.id,
    required this.vehicleId,
    required this.vehicleNumber,
    this.vehicleType,
    required this.vehicleStatus,
    required this.driverId,
    required this.driverName,
    required this.driverMobile,
    required this.driverStatus,
    this.assignedBy,
    this.assignedByName,
    this.assignedAt,
    this.shiftDate,
    this.releasedAt,
    this.remarks,
    required this.isActive,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String?,
      vehicleStatus: json['vehicle_status'] as String? ?? 'UNKNOWN',
      driverId: json['driver_id'] as int,
      driverName: json['driver_name'] as String? ?? '',
      driverMobile: json['driver_mobile'] as String? ?? '',
      driverStatus: json['driver_status'] as String? ?? 'UNKNOWN',
      assignedBy: json['assigned_by'] as int?,
      assignedByName: json['assigned_by_name'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'] as String)
          : null,
      shiftDate: json['shift_date'] != null
          ? DateTime.tryParse(json['shift_date'] as String)
          : null,
      releasedAt: json['released_at'] != null
          ? DateTime.tryParse(json['released_at'] as String)
          : null,
      remarks: json['remarks'] as String?,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}


/// Lightweight status check returned by GET /allocations/vehicle/{id}/status
class VehicleAssignmentStatus {

  final int vehicleId;
  final String vehicleNumber;
  final String vehicleStatus;
  final bool isAssigned;
  final int? assignmentId;
  final int? driverId;
  final String? driverName;
  final String? driverMobile;
  final String? driverStatus;
  final DateTime? shiftDate;

  const VehicleAssignmentStatus({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.vehicleStatus,
    required this.isAssigned,
    this.assignmentId,
    this.driverId,
    this.driverName,
    this.driverMobile,
    this.driverStatus,
    this.shiftDate,
  });

  factory VehicleAssignmentStatus.fromJson(Map<String, dynamic> json) {
    return VehicleAssignmentStatus(
      vehicleId: json['vehicle_id'] as int,
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      vehicleStatus: json['vehicle_status'] as String? ?? '',
      isAssigned: json['is_assigned'] as bool? ?? false,
      assignmentId: json['assignment_id'] as int?,
      driverId: json['driver_id'] as int?,
      driverName: json['driver_name'] as String?,
      driverMobile: json['driver_mobile'] as String?,
      driverStatus: json['driver_status'] as String?,
      shiftDate: json['shift_date'] != null
          ? DateTime.tryParse(json['shift_date'] as String)
          : null,
    );
  }
}
