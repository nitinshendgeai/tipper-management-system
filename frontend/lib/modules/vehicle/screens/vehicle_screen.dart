import 'package:flutter/material.dart';

import '../models/vehicle_model.dart';
import '../services/vehicle_service.dart';
import '../widgets/vehicle_card.dart';
import 'add_vehicle_screen.dart';
import 'edit_vehicle_screen.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final VehicleService _vehicleService = VehicleService();

  late Future<List<VehicleModel>> _vehiclesFuture;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  void _loadVehicles() {
    setState(() {
      _vehiclesFuture = _vehicleService.getVehicles();
    });
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  Future<void> _openAddVehicle() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );

    if (result == true) {
      _loadVehicles();
    }
  }

  Future<void> _openEditVehicle(VehicleModel vehicle) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditVehicleScreen(vehicle: vehicle)),
    );

    if (result == true) {
      _loadVehicles();
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(VehicleModel vehicle) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Vehicle'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${vehicle.vehicleNumber}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteVehicle(vehicle);
    }
  }

  Future<void> _deleteVehicle(VehicleModel vehicle) async {
    try {
      await _vehicleService.deleteVehicle(vehicle.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vehicle.vehicleNumber} deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadVehicles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e, 'Failed to delete vehicle')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── Error Parsing ────────────────────────────────────────────────────────

  String _parseError(Object e, String fallback) {
    final msg = e.toString();

    if (msg.contains('401')) return 'Unauthorized — please login again.';
    if (msg.contains('403')) {
      return 'Permission denied — admin access required.';
    }
    if (msg.contains('404')) return 'Vehicle not found.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server — check your connection.';
    }

    return fallback;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadVehicles,
          ),
        ],
      ),

      // ── FAB: fixed, always visible ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),

      body: FutureBuilder<List<VehicleModel>>(
        future: _vehiclesFuture,

        builder: (context, snapshot) {
          // ── Loading ──────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Error ────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 72,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load vehicles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _parseError(snapshot.error!, 'Unknown error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadVehicles,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final vehicles = snapshot.data ?? [];

          // ── Empty state ──────────────────────────────────────────────────
          if (vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fire_truck_outlined,
                    size: 80,
                    color: Colors.grey[350],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Vehicles Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add Vehicle" below to get started.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // ── Vehicle list ─────────────────────────────────────────────────
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];

              return VehicleCard(
                vehicle: vehicle,
                onEdit: () => _openEditVehicle(vehicle),
                onDelete: () => _confirmDelete(vehicle),
              );
            },
          );
        },
      ),
    );
  }
}
