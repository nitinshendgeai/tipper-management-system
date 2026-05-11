class DriverModel {

  final int id;
  final int? vehicleId;

  final String fullName;
  final String mobileNumber;

  final String licenseNumber;
  final String licenseExpiry;

  final String aadhaarNumber;
  final String address;

  final String emergencyContact;

  /// Operational status: OFF_DUTY | AVAILABLE | ON_TRIP | BREAK
  final String status;

  const DriverModel({
    required this.id,
    this.vehicleId,
    required this.fullName,
    required this.mobileNumber,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.aadhaarNumber,
    required this.address,
    required this.emergencyContact,
    this.status = 'OFF_DUTY',
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {

    return DriverModel(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int?,
      fullName: json['full_name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      licenseNumber: json['license_number'] as String? ?? '',
      licenseExpiry: json['license_expiry'] as String? ?? '',
      aadhaarNumber: json['aadhaar_number'] as String? ?? '',
      address: json['address'] as String? ?? '',
      emergencyContact: json['emergency_contact'] as String? ?? '',
      status: json['status'] as String? ?? 'OFF_DUTY',
    );
  }

  Map<String, dynamic> toJson() {

    return {
      if (vehicleId != null) 'vehicle_id': vehicleId,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'license_number': licenseNumber,
      'license_expiry': licenseExpiry,
      'aadhaar_number': aadhaarNumber,
      'address': address,
      'emergency_contact': emergencyContact,
    };
  }
}
