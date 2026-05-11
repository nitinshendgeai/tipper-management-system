class TripModel {
  final int id;
  final String tripStatus;

  // Vehicle
  final int vehicleId;
  final String vehicleNumber;
  final String vehicleStatus;

  // Driver (auto-fetched from assignment)
  final int driverId;
  final String driverName;
  final String driverMobile;
  final String driverStatus;

  // Route
  final int? routeId;
  final String? routeLabel;
  final String? sourceLocation;
  final String? destinationLocation;

  // AI route intelligence
  final double? calculatedDistanceKm;
  final int? estimatedDurationMin;
  final double? estimatedDiesel;
  final double? distanceKmOverride;

  // Timestamps
  final DateTime? tripDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  // Operational
  final double? startKm;
  final double? endKm;
  final double? dieselIssued;
  final double? dieselUsed;
  final double? tripAdvance;
  final double? tripExpense;
  final double? tollExpense;
  final double? driverBata;
  final double? revenueAmount;
  final double? totalLoggedExpense;

  final String? remarks;
  final DateTime? createdAt;

  const TripModel({
    required this.id,
    required this.tripStatus,
    required this.vehicleId,
    required this.vehicleNumber,
    required this.vehicleStatus,
    required this.driverId,
    required this.driverName,
    required this.driverMobile,
    required this.driverStatus,
    this.routeId,
    this.routeLabel,
    this.sourceLocation,
    this.destinationLocation,
    this.calculatedDistanceKm,
    this.estimatedDurationMin,
    this.estimatedDiesel,
    this.distanceKmOverride,
    this.tripDate,
    this.startTime,
    this.endTime,
    this.cancelledAt,
    this.cancellationReason,
    this.startKm,
    this.endKm,
    this.dieselIssued,
    this.dieselUsed,
    this.tripAdvance,
    this.tripExpense,
    this.tollExpense,
    this.driverBata,
    this.revenueAmount,
    this.totalLoggedExpense,
    this.remarks,
    this.createdAt,
  });

  // ─── Status helpers ──────────────────────────────────────────────────────

  bool get isCreated => tripStatus == 'CREATED';
  bool get isStarted => tripStatus == 'STARTED';
  bool get isCompleted => tripStatus == 'COMPLETED';
  bool get isCancelled => tripStatus == 'CANCELLED';
  bool get isActive => isCreated || isStarted;

  // ─── fromJson ────────────────────────────────────────────────────────────

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as int,
      tripStatus: (json['trip_status'] as String? ?? 'CREATED').toUpperCase(),

      vehicleId: json['vehicle_id'] as int? ?? 0,
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      vehicleStatus: json['vehicle_status'] as String? ?? 'UNKNOWN',

      driverId: json['driver_id'] as int? ?? 0,
      driverName: json['driver_name'] as String? ?? '',
      driverMobile: json['driver_mobile'] as String? ?? '',
      driverStatus: json['driver_status'] as String? ?? 'UNKNOWN',

      routeId: json['route_id'] as int?,
      routeLabel: json['route_label'] as String?,
      sourceLocation: json['source_location'] as String?,
      destinationLocation: json['destination_location'] as String?,

      calculatedDistanceKm: (json['calculated_distance_km'] as num?)
          ?.toDouble(),
      estimatedDurationMin: json['estimated_duration_min'] as int?,
      estimatedDiesel: (json['estimated_diesel'] as num?)?.toDouble(),
      distanceKmOverride: (json['distance_km_override'] as num?)?.toDouble(),

      tripDate: _parseDate(json['trip_date']),
      startTime: _parseDate(json['start_time']),
      endTime: _parseDate(json['end_time']),
      cancelledAt: _parseDate(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] as String?,

      startKm: (json['start_km'] as num?)?.toDouble(),
      endKm: (json['end_km'] as num?)?.toDouble(),

      dieselIssued: (json['diesel_issued'] as num?)?.toDouble(),
      dieselUsed: (json['diesel_used'] as num?)?.toDouble(),
      tripAdvance: (json['trip_advance'] as num?)?.toDouble(),
      tripExpense: (json['trip_expense'] as num?)?.toDouble(),
      tollExpense: (json['toll_expense'] as num?)?.toDouble(),
      driverBata: (json['driver_bata'] as num?)?.toDouble(),
      revenueAmount: (json['revenue_amount'] as num?)?.toDouble(),
      totalLoggedExpense: (json['total_logged_expense'] as num?)?.toDouble(),

      remarks: json['remarks'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }
}
