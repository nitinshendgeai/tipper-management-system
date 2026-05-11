import 'package:flutter/material.dart';

import '../../vehicle/models/vehicle_model.dart';
import '../../vehicle/services/vehicle_service.dart';
import '../services/driver_service.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DriverService _driverService = DriverService();
  final VehicleService _vehicleService = VehicleService();

  bool _isLoading = false;
  bool _isLoadingVehicles = false;
  List<VehicleModel> _vehicles = [];
  int? _selectedVehicleId;

  // ─── Controllers ─────────────────────────────────────────────────────────
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _licenseExpiryController =
      TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _aadhaarController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  // ─── Load vehicle dropdown ────────────────────────────────────────────────

  Future<void> _fetchVehicles() async {
    setState(() => _isLoadingVehicles = true);

    try {
      final vehicles = await _vehicleService.getVehicles();
      if (mounted) setState(() => _vehicles = vehicles);
    } catch (_) {
      // Non-fatal — vehicle dropdown just stays empty
    } finally {
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'mobile_number': _mobileController.text.trim(),
        'license_number': _licenseNumberController.text.trim().toUpperCase(),
        'license_expiry': _licenseExpiryController.text.trim(),
        'aadhaar_number': _aadhaarController.text.trim(),
        'address': _addressController.text.trim(),
        'emergency_contact': _emergencyContactController.text.trim(),
        if (_selectedVehicleId != null) 'vehicle_id': _selectedVehicleId,
      };

      await _driverService.createDriver(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // triggers list refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(Object e) {
    final msg = e.toString();

    if (msg.contains('already exists')) {
      return 'A driver with this license number already exists.';
    }
    if (msg.contains('401')) return 'Session expired — please login again.';
    if (msg.contains('403')) {
      return 'Permission denied — admin access required.';
    }
    if (msg.contains('422')) return 'Invalid data — check all fields.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server — check your connection.';
    }

    return 'Failed to save driver. Please try again.';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Driver')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ── Section: Personal Details ────────────────────────────
              _sectionHeader('Personal Details'),
              const SizedBox(height: 16),

              _buildField(
                controller: _fullNameController,
                label: 'Full Name *',
                hint: 'Driver\'s full legal name',
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Full name is required'
                    : null,
              ),

              _buildField(
                controller: _mobileController,
                label: 'Mobile Number *',
                hint: '10-digit mobile number',
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Mobile number is required';
                  }
                  if (v.trim().length < 10) {
                    return 'Enter a valid 10-digit number';
                  }
                  return null;
                },
              ),

              _buildField(
                controller: _aadhaarController,
                label: 'Aadhaar Number *',
                hint: '12-digit Aadhaar number',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Aadhaar number is required';
                  }
                  if (v.trim().length < 12) {
                    return 'Enter a valid 12-digit Aadhaar number';
                  }
                  return null;
                },
              ),

              _buildField(
                controller: _addressController,
                label: 'Address *',
                hint: 'Residential address',
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Address is required'
                    : null,
              ),

              _buildField(
                controller: _emergencyContactController,
                label: 'Emergency Contact *',
                hint: 'Emergency contact number',
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Emergency contact is required';
                  }
                  if (v.trim().length < 10) {
                    return 'Enter a valid contact number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Section: License Details ─────────────────────────────
              _sectionHeader('License Details'),
              const SizedBox(height: 16),

              _buildField(
                controller: _licenseNumberController,
                label: 'License Number *',
                hint: 'e.g. MH1220110012345',
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'License number is required';
                  }
                  if (v.trim().length < 6) {
                    return 'Enter a valid license number';
                  }
                  return null;
                },
              ),

              _buildField(
                controller: _licenseExpiryController,
                label: 'License Expiry *',
                hint: 'YYYY-MM-DD',
                keyboardType: TextInputType.datetime,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'License expiry is required';
                  }
                  final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                  if (!regex.hasMatch(v.trim())) {
                    return 'Use format: YYYY-MM-DD';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Section: Vehicle Assignment ──────────────────────────
              _sectionHeader('Vehicle Assignment'),
              const SizedBox(height: 4),
              Text(
                'Optional — assign a vehicle to this driver',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),

              _buildVehicleDropdown(),

              const SizedBox(height: 30),

              // ── Save Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'SAVE DRIVER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Vehicle Dropdown ─────────────────────────────────────────────────────

  Widget _buildVehicleDropdown() {
    if (_isLoadingVehicles) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int?>(
        initialValue: _selectedVehicleId,
        decoration: const InputDecoration(
          labelText: 'Assigned Vehicle (optional)',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(Icons.fire_truck_outlined),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('— No vehicle assigned —'),
          ),
          ..._vehicles.map(
            (v) => DropdownMenuItem<int?>(
              value: v.id,
              child: Text('${v.vehicleNumber} (${v.vehicleType})'),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _selectedVehicleId = value),
      ),
    );
  }

  // ─── Helper Widgets ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: validator,
      ),
    );
  }
}
