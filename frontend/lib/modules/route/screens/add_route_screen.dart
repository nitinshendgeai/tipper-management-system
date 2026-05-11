import 'package:flutter/material.dart';

import '../services/route_service.dart';

class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RouteService _routeService = RouteService();

  bool _isLoading = false;

  // ─── Controllers ─────────────────────────────────────────────────────────
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _distanceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'source_location': _sourceController.text.trim(),
        'destination_location': _destinationController.text.trim(),
        'distance_km': double.parse(_distanceController.text.trim()),
        if (_remarksController.text.trim().isNotEmpty)
          'remarks': _remarksController.text.trim(),
      };

      await _routeService.createRoute(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route added successfully!'),
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
      return 'A route between these locations already exists.';
    }
    if (msg.contains('401')) return 'Session expired — please login again.';
    if (msg.contains('403')) {
      return 'Permission denied — admin access required.';
    }
    if (msg.contains('422')) return 'Invalid data — check all fields.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server — check your connection.';
    }

    return 'Failed to save route. Please try again.';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Route')),

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
                hint: 'e.g. Mumbai',
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
                hint: 'e.g. Pune',
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
              const SizedBox(height: 4),
              Text(
                'Optional — add any notes or remarks for this route',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
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

              // ── Save Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
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
                          'SAVE ROUTE',
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
