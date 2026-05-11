import 'package:flutter/material.dart';

import '../services/vehicle_service.dart';

class AddVehicleScreen extends StatefulWidget {

  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final VehicleService _vehicleService = VehicleService();

  bool _isLoading = false;

  // ─── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _vehicleTypeController =
      TextEditingController();
  final TextEditingController _capacityController =
      TextEditingController();
  final TextEditingController _ownerController =
      TextEditingController();
  final TextEditingController _mobileController =
      TextEditingController();
  final TextEditingController _rcController =
      TextEditingController();
  final TextEditingController _insuranceController =
      TextEditingController();

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vehicleTypeController.dispose();
    _capacityController.dispose();
    _ownerController.dispose();
    _mobileController.dispose();
    _rcController.dispose();
    _insuranceController.dispose();
    super.dispose();
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _saveVehicle() async {

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {

      await _vehicleService.createVehicle({
        'vehicle_number':
            _vehicleNumberController.text.trim().toUpperCase(),
        'vehicle_type': _vehicleTypeController.text.trim(),
        'capacity_ton': int.parse(_capacityController.text.trim()),
        'owner_name': _ownerController.text.trim(),
        'mobile_number': _mobileController.text.trim(),
        'rc_number': _rcController.text.trim(),
        'insurance_expiry': _insuranceController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Return true so VehicleScreen knows to refresh
        Navigator.pop(context, true);
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

    if (msg.contains('already exists')) return 'Vehicle number already exists.';
    if (msg.contains('401')) return 'Session expired — please login again.';
    if (msg.contains('403')) return 'Permission denied — admin access required.';
    if (msg.contains('422')) return 'Invalid data — check all fields.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server — check your connection.';
    }

    return 'Failed to save vehicle. Please try again.';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('Add Vehicle'),
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Form(

          key: _formKey,

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // ── Section: Vehicle Information ─────────────────────────────
              _sectionHeader('Vehicle Information'),
              const SizedBox(height: 16),

              _buildField(
                controller: _vehicleNumberController,
                label: 'Vehicle Number *',
                hint: 'e.g. MH12AB1234',
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vehicle number is required';
                  }
                  if (v.trim().length < 6) {
                    return 'Enter a valid vehicle number';
                  }
                  return null;
                },
              ),

              _buildField(
                controller: _vehicleTypeController,
                label: 'Vehicle Type *',
                hint: 'e.g. Tipper, Truck, Dumper',
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Vehicle type is required'
                        : null,
              ),

              _buildField(
                controller: _capacityController,
                label: 'Capacity (Ton) *',
                hint: 'e.g. 10',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Capacity is required';
                  }
                  final parsed = int.tryParse(v.trim());
                  if (parsed == null) return 'Must be a whole number';
                  if (parsed <= 0) return 'Capacity must be greater than 0';
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Section: Owner Details ───────────────────────────────────
              _sectionHeader('Owner Details'),
              const SizedBox(height: 16),

              _buildField(
                controller: _ownerController,
                label: 'Owner Name *',
                hint: 'Full name',
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Owner name is required'
                        : null,
              ),

              _buildField(
                controller: _mobileController,
                label: 'Mobile Number *',
                hint: '10-digit mobile',
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

              const SizedBox(height: 4),

              // ── Section: Documents ───────────────────────────────────────
              _sectionHeader('Documents'),
              const SizedBox(height: 16),

              _buildField(
                controller: _rcController,
                label: 'RC Number *',
                hint: 'Registration certificate number',
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'RC number is required'
                        : null,
              ),

              _buildField(
                controller: _insuranceController,
                label: 'Insurance Expiry *',
                hint: 'YYYY-MM-DD',
                keyboardType: TextInputType.datetime,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Insurance expiry is required';
                  }
                  final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                  if (!regex.hasMatch(v.trim())) {
                    return 'Use format: YYYY-MM-DD';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              // ── Save Button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveVehicle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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
                          'SAVE VEHICLE',
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

  // ─── Helper Widgets ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {

    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
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
    String? Function(String?)? validator,
  }) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }
}
