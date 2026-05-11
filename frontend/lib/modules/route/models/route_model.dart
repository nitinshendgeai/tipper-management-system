class RouteModel {
  final int id;
  final String sourceLocation;
  final String destinationLocation;

  // FIX: was 'int' — backend returns float, caused runtime type crash
  final double distanceKm;

  // Optional operational fields (used by trip module)
  final double? tripRate;
  final double? dieselLimit;
  final double? estimatedHours;

  // Optional free-text notes
  final String? remarks;

  const RouteModel({
    required this.id,
    required this.sourceLocation,
    required this.destinationLocation,
    required this.distanceKm,
    this.tripRate,
    this.dieselLimit,
    this.estimatedHours,
    this.remarks,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as int,
      sourceLocation: json['source_location'] as String? ?? '',
      destinationLocation: json['destination_location'] as String? ?? '',
      // Guard: backend may return int (e.g. 10) or double (10.0) — cast safely
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      tripRate: (json['trip_rate'] as num?)?.toDouble(),
      dieselLimit: (json['diesel_limit'] as num?)?.toDouble(),
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble(),
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source_location': sourceLocation,
      'destination_location': destinationLocation,
      'distance_km': distanceKm,
      if (tripRate != null) 'trip_rate': tripRate,
      if (dieselLimit != null) 'diesel_limit': dieselLimit,
      if (estimatedHours != null) 'estimated_hours': estimatedHours,
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
    };
  }
}
