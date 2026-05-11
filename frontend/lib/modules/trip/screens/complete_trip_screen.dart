import 'package:flutter/material.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';

class CompleteTripScreen extends StatefulWidget {
  final TripModel trip;

  const CompleteTripScreen({super.key, required this.trip});

  @override
  State<CompleteTripScreen> createState() => _CompleteTripScreenState();
}

class _CompleteTripScreenState extends State<CompleteTripScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TripService _tripService = TripService();

  bool _isLoading = false;

  // ─── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _endKmController = TextEditingController();
  final TextEditingController _dieselUsedController = TextEditingController();
  final TextEditingController _tripExpenseController = TextEditingController();
  final TextEditingController _tollExpenseController = TextEditingController();
  final TextEditingController _driverBataController = TextEditingController();
  final TextEditingController _revenueAmountController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill remarks from existing trip
    if (widget.trip.remarks != null) {
      _remarksController.text = widget.trip.remarks!;
    }
  }

  @override
  void dispose() {
    _endKmController.dispose();
    _dieselUsedController.dispose();
    _tripExpenseController.dispose();
    _tollExpenseController.dispose();
    _driverBataController.dispose();
    _revenueAmountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // ─── Complete ──────────────────────────────────────────────────────────────

  Future<void> _completeTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'end_km': double.parse(_endKmController.text.trim()),
        'diesel_used': double.parse(_dieselUsedController.text.trim()),
        'trip_expense': double.parse(_tripExpenseController.text.trim()),
      };

      final toll = _tollExpenseController.text.trim();
      if (toll.isNotEmpty) payload['toll_expense'] = double.parse(toll);

      final bata = _driverBataController.text.trim();
      if (bata.isNotEmpty) payload['driver_bata'] = double.parse(bata);

      final revenue = _revenueAmountController.text.trim();
      if (revenue.isNotEmpty) payload['revenue_amount'] = double.parse(revenue);

      final remarks = _remarksController.text.trim();
      if (remarks.isNotEmpty) payload['remarks'] = remarks;

      await _tripService.completeTrip(widget.trip.id, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip completed successfully!'),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(Object e) {
    final msg = e.toString();

    if (msg.contains('401')) return 'Session expired — please login again.';
    if (msg.contains('403')) {
      return 'Permission denied — admin access required.';
    }
    if (msg.contains('End KM') || msg.contains('end_km')) {
      return 'End KM must be greater than Start KM.';
    }
    if (msg.contains('409')) {
      return 'Trip cannot be completed in its current status.';
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server — check your connection.';
    }

    return 'Failed to complete trip. Please try again.';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Complete Trip #${trip.id}',
          overflow: TextOverflow.ellipsis,
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Trip summary card ─────────────────────────────────────────
              _buildSummaryCard(trip),

              const SizedBox(height: 24),

              // ── Section: Odometer ─────────────────────────────────────────
              _sectionHeader('Odometer Reading'),
              const SizedBox(height: 16),

              _buildField(
                controller: _endKmController,
                label: 'End KM *',
                hint: trip.startKm != null
                    ? 'Must be > ${trip.startKm!.toStringAsFixed(0)}'
                    : 'e.g. 45680',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.flag_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'End KM is required';
                  }
                  final n = double.tryParse(v.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n <= 0) return 'KM must be greater than 0';
                  if (trip.startKm != null && n <= trip.startKm!) {
                    return 'End KM must be greater than Start KM (${trip.startKm!.toStringAsFixed(0)})';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Section: Fuel ─────────────────────────────────────────────
              _sectionHeader('Fuel'),
              const SizedBox(height: 16),

              _buildField(
                controller: _dieselUsedController,
                label: 'Diesel Used (litres) *',
                hint: 'e.g. 65',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.local_gas_station_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Diesel used is required';
                  }
                  final n = double.tryParse(v.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n < 0) return 'Cannot be negative';
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Section: Expenses ─────────────────────────────────────────
              _sectionHeader('Expenses'),
              const SizedBox(height: 16),

              _buildField(
                controller: _tripExpenseController,
                label: 'Trip Expense (₹) *',
                hint: 'e.g. 1200',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.receipt_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Trip expense is required';
                  }
                  final n = double.tryParse(v.trim());
                  if (n == null) return 'Enter a valid amount';
                  if (n < 0) return 'Cannot be negative';
                  return null;
                },
              ),

              _buildField(
                controller: _tollExpenseController,
                label: 'Toll Expense (₹, optional)',
                hint: 'e.g. 150',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.toll_outlined,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null) return 'Enter a valid amount';
                    if (n < 0) return 'Cannot be negative';
                  }
                  return null;
                },
              ),

              _buildField(
                controller: _driverBataController,
                label: 'Driver Bata (₹, optional)',
                hint: 'e.g. 300',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.person_outlined,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null) return 'Enter a valid amount';
                    if (n < 0) return 'Cannot be negative';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Section: Revenue ──────────────────────────────────────────
              _sectionHeader('Revenue'),
              const SizedBox(height: 16),

              _buildField(
                controller: _revenueAmountController,
                label: 'Revenue Amount (₹, optional)',
                hint: 'e.g. 8500',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.currency_rupee,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null) return 'Enter a valid amount';
                    if (n < 0) return 'Cannot be negative';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Section: Additional Info ───────────────────────────────────
              _sectionHeader('Additional Info'),
              const SizedBox(height: 12),

              _buildField(
                controller: _remarksController,
                label: 'Remarks (optional)',
                hint: 'e.g. Delivery completed on time',
                prefixIcon: Icons.notes_outlined,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 30),

              // ── Complete button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
                          'COMPLETE TRIP',
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

  // ─── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(TripModel trip) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trip.sourceLocation}  →  ${trip.destinationLocation}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vehicle: ${trip.vehicleNumber}   Driver: ${trip.driverName}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          if (trip.startKm != null) ...[
            const SizedBox(height: 4),
            Text(
              'Start KM: ${trip.startKm!.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helper widgets ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.teal,
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
