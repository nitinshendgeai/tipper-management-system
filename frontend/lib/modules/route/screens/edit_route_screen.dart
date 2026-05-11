import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/route_service.dart';

class EditRouteScreen extends StatefulWidget {
  final RouteModel route;

  const EditRouteScreen({super.key, required this.route});

  @override
  State<EditRouteScreen> createState() => _EditRouteScreenState();
}

class _EditRouteScreenState extends State<EditRouteScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RouteService _routeService = RouteService();

  bool _isLoading = false;

  // ─── Controllers — pre-filled from widget.route ───────────────────────────
  late final TextEditingController _sourceController;
  late final TextEditingController _destinationController;
  late final TextEditingController _distanceController;
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();

    final r = widget.route;

    _sourceController = TextEditingController(text: r.sourceLocation);
    _destinationController = TextEditingController(text: r.destinationLocation);
    _distanceController = TextEditingController(
      text: r.distanceKm.toStringAsFixed(1),
    );
    _remarksController = TextEditingController(text: r.remarks ?? '');
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _distanceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  Future<void> _updateRoute() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'source_location': _sourceController.text.trim(),
        'destination_location': _destinationController.text.trim(),
        'distance_km': double.parse(_distanceController.text.trim()),
        // Send remarks always — empty string clears it; null preserves old value
        'remarks': _remarksController.text.trim().isNotEmpty
            ? _remarksController.text.trim()
            : null,
      };

      await _routeService.updateRoute(widget.route.id, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route updated successfully!'),
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

    if (msg.contains('401')) return 'Session expired — please login again.';
    if (msg.contains('403')) {
      return 'Permission denied — admin access required.';
    }
    if (msg.contains('404')) return 'Route not found.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server — check your connection.';
    }

    return 'Failed to update route. Please try again.';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.route.sourceLocation} → ${widget.route.destinationLocation}',
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
              // ── Section: Route Details ───────────────────────────────
              _sectionHeader('Route Details'),
              const SizedBox(height: 16),

              _buildField(
                controller: _sourceController,
                label: 'Source Location *',
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.location_on_outlined,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Source location is required'
                    : null,
              ),

              // Direction indicator
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: 18,
                      color: Colors.teal[400],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'to',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),

              _buildField(
                controller: _destinationController,
                label: 'Destination Location *',
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.location_on,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Destination location is required';
                  }
                  if (v.trim().toLowerCase() ==
                      _sourceController.text.trim().toLowerCase()) {
                    return 'Source and destination cannot be the same';
                  }
                  return null;
                },
              ),

              _buildField(
                controller: _distanceController,
                label: 'Distance (KM) *',
                hint: 'e.g. 148.5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.straighten,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Distance is required';
                  }
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null) {
                    return 'Enter a valid number (e.g. 148.5)';
                  }
                  if (parsed <= 0) {
                    return 'Distance must be greater than 0';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Section: Additional Info ─────────────────────────────
              _sectionHeader('Additional Info'),
              const SizedBox(height: 12),

              _buildField(
                controller: _remarksController,
                label: 'Remarks (optional)',
                hint: 'e.g. Toll road, avoid monsoon season',
                prefixIcon: Icons.notes_outlined,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 30),

              // ── Update Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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
                          'UPDATE ROUTE',
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
