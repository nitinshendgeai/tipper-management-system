import 'package:flutter/material.dart';

import '../../vehicle/models/vehicle_model.dart';
import '../../vehicle/services/vehicle_service.dart';
import '../../driver/models/driver_model.dart';
import '../../driver/services/driver_service.dart';
import '../services/allocation_service.dart';

class CreateAssignmentScreen extends StatefulWidget {

  const CreateAssignmentScreen({super.key});

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AllocationService _service = AllocationService();

  List<VehicleModel> _vehicles = [];
  List<DriverModel> _drivers = [];

  int? _selectedVehicleId;
  int? _selectedDriverId;

  bool _loadingDropdowns = true;
  String? _dropdownError;
  bool _isSubmitting = false;

  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() { _loadingDropdowns = true; _dropdownError = null; });
    try {
      final results = await Future.wait([
        VehicleService().getVehicles(),
        DriverService().getDrivers(),
      ]);
      if (mounted) {
        setState(() {
          // Only show AVAILABLE vehicles (not ON_TRIP, not MAINTENANCE)
          _vehicles = (results[0] as List<VehicleModel>)
              .where((v) => v.status == 'AVAILABLE')
              .toList();
          // Only show available drivers (OFF_DUTY or AVAILABLE without active assignment)
          _drivers = (results[1] as List<DriverModel>)
              .where((d) => d.status == 'OFF_DUTY' || d.status == 'AVAILABLE')
              .toList();
          _loadingDropdowns = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _dropdownError = 'Failed to load data. Tap retry.'; _loadingDropdowns = false; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final payload = <String, dynamic>{
        'vehicle_id': _selectedVehicleId,
        'driver_id': _selectedDriverId,
        if (_remarksController.text.trim().isNotEmpty)
          'remarks': _remarksController.text.trim(),
      };

      await _service.createAssignment(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver assigned to vehicle successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('409')) return 'Vehicle or driver already has an active assignment.';
    if (msg.contains('403')) return 'Permission denied — supervisor access required.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server — check your connection.';
    }
    return 'Failed to create assignment. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Driver to Vehicle')),
      body: _loadingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : _dropdownError != null
              ? _buildError()
              : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(_dropdownError!, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(onPressed: _loadDropdowns, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Info banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.indigo[700], size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Assigning a driver starts their attendance shift automatically. Only AVAILABLE vehicles and drivers are shown.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _sectionHeader('Select Vehicle'),
            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              value: _selectedVehicleId,
              decoration: const InputDecoration(
                labelText: 'Vehicle *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fire_truck_outlined),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _vehicles.isEmpty
                  ? [const DropdownMenuItem(value: -1, child: Text('No available vehicles'))]
                  : _vehicles.map((v) => DropdownMenuItem<int>(
                        value: v.id,
                        child: Text('${v.vehicleNumber} — ${v.vehicleType ?? ''}'),
                      )).toList(),
              onChanged: (val) => setState(() => _selectedVehicleId = val),
              validator: (v) => (v == null || v == -1) ? 'Please select a vehicle' : null,
            ),

            const SizedBox(height: 20),
            _sectionHeader('Select Driver'),
            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              value: _selectedDriverId,
              decoration: const InputDecoration(
                labelText: 'Driver *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _drivers.isEmpty
                  ? [const DropdownMenuItem(value: -1, child: Text('No available drivers'))]
                  : _drivers.map((d) => DropdownMenuItem<int>(
                        value: d.id,
                        child: Text('${d.fullName}  •  ${d.mobileNumber}'),
                      )).toList(),
              onChanged: (val) => setState(() => _selectedDriverId = val),
              validator: (v) => (v == null || v == -1) ? 'Please select a driver' : null,
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: _remarksController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('ASSIGN DRIVER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 0.3),
  );
}
