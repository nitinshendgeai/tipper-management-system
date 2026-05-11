class VehicleModel {
  final int id;
  final String vehicleNumber;
  final String vehicleType;
  final int capacityTon;
  final String ownerName;
  final String mobileNumber;
  final String rcNumber;
  final String insuranceExpiry;

  /// Operational status: AVAILABLE | ASSIGNED | ON_TRIP | MAINTENANCE
  final String status;

  VehicleModel({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.capacityTon,
    required this.ownerName,
    required this.mobileNumber,
    required this.rcNumber,
    required this.insuranceExpiry,
    this.status = 'AVAILABLE',
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int,
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? '',
      capacityTon: json['capacity_ton'] as int? ?? 0,
      ownerName: json['owner_name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      rcNumber: json['rc_number'] as String? ?? '',
      insuranceExpiry: json['insurance_expiry'] as String? ?? '',
      status: json['status'] as String? ?? 'AVAILABLE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'capacity_ton': capacityTon,
      'owner_name': ownerName,
      'mobile_number': mobileNumber,
      'rc_number': rcNumber,
      'insurance_expiry': insuranceExpiry,
    };
  }
}
