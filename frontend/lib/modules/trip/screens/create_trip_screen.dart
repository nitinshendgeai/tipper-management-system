import 'package:flutter/material.dart';

import '../../vehicle/models/vehicle_model.dart';
import '../../vehicle/services/vehicle_service.dart';
import '../../allocation/services/allocation_service.dart';
import '../../allocation/models/assignment_model.dart';
import '../../route/models/route_model.dart';
import '../../route/services/route_service.dart';

import '../services/trip_service.dart';
import '../services/route_intelligence_service.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TripService _tripService = TripService();
  final AllocationService _allocationService = AllocationService();
  final RouteIntelligenceService _routeIntelService =
      RouteIntelligenceService();

  // ─── Dropdown data ─────────────────────────────────────────────────────────
  List<VehicleModel> _vehicles = [];
  List<RouteModel> _routes = [];

  int? _selectedVehicleId;
  int? _selectedRouteId;

  // Auto-fetched driver info
  VehicleAssignmentStatus? _vehicleAssignment;
  bool _fetchingDriver = false;
  String? _driverFetchError;

  // ─── AI Route Intelligence ─────────────────────────────────────────────────
  RouteCalculationResult? _routeCalculation;
  bool _calculatingRoute = false;
  String? _routeCalcError;

  // ─── Form controllers ──────────────────────────────────────────────────────
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _distanceOverrideController =
      TextEditingController();
  final TextEditingController _dieselIssuedController = TextEditingController();
  final TextEditingController _tripAdvanceController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  bool _loadingDropdowns = true;
  String? _dropdownError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _distanceOverrideController.dispose();
    _dieselIssuedController.dispose();
    _tripAdvanceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // ─── Load dropdowns ─────────────────────────────────────────────────────────

  Future<void> _loadDropdowns() async {
    setState(() {
      _loadingDropdowns = true;
      _dropdownError = null;
    });
    try {
      final results = await Future.wait([
        VehicleService().getVehicles(),
        RouteService().getRoutes(),
      ]);
      if (mounted) {
        setState(() {
          // Only show ASSIGNED vehicles (have driver, ready for trip)
          _vehicles = (results[0] as List<VehicleModel>)
              .where((v) => v.status == 'ASSIGNED')
              .toList();
          _routes = results[1] as List<RouteModel>;
          _loadingDropdowns = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dropdownError = 'Failed to load data.';
          _loadingDropdowns = false;
        });
      }
    }
  }

  // ─── Auto-fetch driver when vehicle selected ───────────────────────────────

  Future<void> _onVehicleSelected(int vehicleId) async {
    setState(() {
      _selectedVehicleId = vehicleId;
      _vehicleAssignment = null;
      _driverFetchError = null;
      _fetchingDriver = true;
    });

    try {
      final status = await _allocationService.getVehicleStatus(vehicleId);

      if (mounted) {
        setState(() {
          _vehicleAssignment = status;
          _fetchingDriver = false;

          if (!status.isAssigned) {
            _driverFetchError = 'This vehicle has no active driver assignment.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _driverFetchError = 'Could not fetch driver info.';
          _fetchingDriver = false;
        });
      }
    }
  }

  // ─── AI Route Calculation ──────────────────────────────────────────────────

  Future<void> _calculateRoute() async {
    final src = _sourceController.text.trim();
    final dest = _destinationController.text.trim();

    if (src.isEmpty || dest.isEmpty) return;

    setState(() {
      _calculatingRoute = true;
      _routeCalculation = null;
      _routeCalcError = null;
    });

    try {
      final result = await _routeIntelService.calculateRoute(
        origin: src,
        destination: dest,
      );

      if (mounted) {
        setState(() {
          _routeCalculation = result;
          _calculatingRoute = false;
          // Pre-fill override with calculated distance
          if (_distanceOverrideController.text.isEmpty) {
            _distanceOverrideController.text = result.distanceKm
                .toStringAsFixed(1);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routeCalcError =
              'Route calculation failed. You can enter distance manually.';
          _calculatingRoute = false;
        });
      }
    }
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vehicleAssignment == null || !_vehicleAssignment!.isAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a vehicle with an assigned driver first.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = <String, dynamic>{
        'vehicle_id': _selectedVehicleId,
        'source_location': _sourceController.text.trim(),
        'destination_location': _destinationController.text.trim(),
        if (_selectedRouteId != null) 'route_id': _selectedRouteId,
        if (_routeCalculation != null) ...{
          'calculated_distance_km': _routeCalculation!.distanceKm,
          'estimated_duration_min': _routeCalculation!.durationMin,
          'estimated_diesel': _routeCalculation!.estimatedDieselLitres,
        },
      };

      final overrideText = _distanceOverrideController.text.trim();
      if (overrideText.isNotEmpty) {
        payload['distance_km_override'] = double.parse(overrideText);
      }

      final diesel = _dieselIssuedController.text.trim();
      if (diesel.isNotEmpty) payload['diesel_issued'] = double.parse(diesel);

      final advance = _tripAdvanceController.text.trim();
      if (advance.isNotEmpty) payload['trip_advance'] = double.parse(advance);

      final remarks = _remarksController.text.trim();
      if (remarks.isNotEmpty) payload['remarks'] = remarks;

      await _tripService.createTrip(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip created successfully!'),
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
    if (msg.contains('401')) return 'Session expired — please login again.';
    if (msg.contains('403')) return 'Permission denied.';
    if (msg.contains('no active driver')) {
      return 'Assign a driver to this vehicle first.';
    }
    if (msg.contains('ON_TRIP')) {
      return 'Vehicle or driver is already on a trip.';
    }
    if (msg.contains('409')) {
      return 'Conflict — check active trips or assignments.';
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server — check your connection.';
    }
    return 'Failed to create trip. Please try again.';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Trip')),
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
          ElevatedButton.icon(
            onPressed: _loadDropdowns,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
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
            // ── STEP 1: Vehicle ────────────────────────────────────────────
            _sectionHeader('Step 1 — Select Vehicle'),
            const SizedBox(height: 6),
            Text(
              'Only ASSIGNED vehicles (with active driver) are shown.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              initialValue: _selectedVehicleId,
              decoration: const InputDecoration(
                labelText: 'Vehicle *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fire_truck_outlined),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: _vehicles.isEmpty
                  ? [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('No assigned vehicles available'),
                      ),
                    ]
                  : _vehicles
                        .map(
                          (v) => DropdownMenuItem<int>(
                            value: v.id,
                            child: Text(
                              '${v.vehicleNumber}  —  ${v.vehicleType}',
                            ),
                          ),
                        )
                        .toList(),
              onChanged: (val) {
                if (val != null && val != -1) _onVehicleSelected(val);
              },
              validator: (v) =>
                  (v == null || v == -1) ? 'Please select a vehicle' : null,
            ),

            const SizedBox(height: 12),

            // ── Auto-fetched driver card ────────────────────────────────────
            _buildDriverCard(),

            const SizedBox(height: 20),

            // ── STEP 2: Route / Locations ──────────────────────────────────
            _sectionHeader('Step 2 — Route Details'),
            const SizedBox(height: 12),

            _buildField(
              controller: _sourceController,
              label: 'Source Location *',
              hint: 'e.g. Mumbai, Maharashtra',
              prefixIcon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Source is required' : null,
            ),

            _buildField(
              controller: _destinationController,
              label: 'Destination Location *',
              hint: 'e.g. Pune, Maharashtra',
              prefixIcon: Icons.location_on,
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Destination is required';
                }
                if (v.trim().toLowerCase() ==
                    _sourceController.text.trim().toLowerCase()) {
                  return 'Source and destination cannot be the same';
                }
                return null;
              },
            ),

            // ── AI Calculate Button ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _calculatingRoute ? null : _calculateRoute,
                icon: _calculatingRoute
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _calculatingRoute
                      ? 'Calculating...'
                      : 'AI: Calculate Route Distance & Time',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── AI Result Card ─────────────────────────────────────────────
            if (_routeCalculation != null) _buildRouteResultCard(),
            if (_routeCalcError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _routeCalcError!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Optional route master reference ────────────────────────────
            DropdownButtonFormField<int>(
              initialValue: _selectedRouteId,
              decoration: const InputDecoration(
                labelText: 'Route Master Reference (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.route_outlined),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('None')),
                ..._routes.map(
                  (r) => DropdownMenuItem<int>(
                    value: r.id,
                    child: Text(
                      '${r.sourceLocation} → ${r.destinationLocation}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedRouteId = val),
            ),

            const SizedBox(height: 20),

            // ── STEP 3: Trip Parameters ────────────────────────────────────
            _sectionHeader('Step 3 — Trip Parameters'),
            const SizedBox(height: 12),

            _buildField(
              controller: _distanceOverrideController,
              label: 'Distance Override (km)',
              hint: 'Override AI calculated distance',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Icons.straighten,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Enter a valid distance';
                }
                return null;
              },
            ),

            _buildField(
              controller: _dieselIssuedController,
              label: 'Diesel Issued (litres, optional)',
              hint: 'e.g. 80',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Icons.local_gas_station_outlined,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final n = double.tryParse(v.trim());
                  if (n == null || n < 0) return 'Enter a valid amount';
                }
                return null;
              },
            ),

            _buildField(
              controller: _tripAdvanceController,
              label: 'Trip Advance (₹, optional)',
              hint: 'e.g. 500',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Icons.currency_rupee,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final n = double.tryParse(v.trim());
                  if (n == null || n < 0) return 'Enter a valid amount';
                }
                return null;
              },
            ),

            _buildField(
              controller: _remarksController,
              label: 'Remarks (optional)',
              hint: 'e.g. Priority delivery',
              prefixIcon: Icons.notes_outlined,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'CREATE TRIP',
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
    );
  }

  // ─── Auto-driver card ──────────────────────────────────────────────────────

  Widget _buildDriverCard() {
    if (_selectedVehicleId == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(
              'Select a vehicle to auto-fetch assigned driver',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_fetchingDriver) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Fetching assigned driver...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_driverFetchError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _driverFetchError!,
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    if (_vehicleAssignment != null && _vehicleAssignment!.isAssigned) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _vehicleAssignment!.driverName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AUTO-ASSIGNED',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _vehicleAssignment!.driverMobile ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ─── AI route result card ──────────────────────────────────────────────────

  Widget _buildRouteResultCard() {
    final r = _routeCalculation!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.deepPurple,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                r.isGoogleMaps
                    ? 'Google Maps Calculation'
                    : 'Estimated Calculation',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _aiStat(
                Icons.straighten,
                'Distance',
                r.rawDistanceText ?? '${r.distanceKm.toStringAsFixed(1)} km',
              ),
              _aiStat(
                Icons.timer_outlined,
                'Duration',
                r.rawDurationText ?? '${r.durationMin} min',
              ),
              _aiStat(
                Icons.local_gas_station_outlined,
                'Est. Diesel',
                '${r.estimatedDieselLitres.toStringAsFixed(1)} L',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiStat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.deepPurple[300]),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ─── Helper widgets ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.teal,
      letterSpacing: 0.3,
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    IconData? prefixIcon,
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
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        ),
        validator: validator,
      ),
    );
  }
}
