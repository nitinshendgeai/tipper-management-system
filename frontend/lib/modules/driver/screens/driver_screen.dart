import 'package:flutter/material.dart';

import '../models/driver_model.dart';
import '../services/driver_service.dart';
import '../widgets/driver_card.dart';
import 'add_driver_screen.dart';
import 'edit_driver_screen.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final DriverService _driverService = DriverService();

  late Future<List<DriverModel>> _driversFuture;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  void _loadDrivers() {
    setState(() {
      _driversFuture = _driverService.getDrivers();
    });
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  Future<void> _openAddDriver() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddDriverScreen()),
    );

    if (result == true) _loadDrivers();
  }

  Future<void> _openEditDriver(DriverModel driver) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditDriverScreen(driver: driver)),
    );

    if (result == true) _loadDrivers();
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(DriverModel driver) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Driver'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${driver.fullName}"?\n\nThis action cannot be undone.',
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

    if (confirmed == true) await _deleteDriver(driver);
  }

  Future<void> _deleteDriver(DriverModel driver) async {
    try {
      await _driverService.deleteDriver(driver.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${driver.fullName} deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadDrivers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e, 'Failed to delete driver')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── Error helper ─────────────────────────────────────────────────────────

  String _parseError(Object e, String fallback) {
    final msg = e.toString();

    if (msg.contains('401')) return 'Unauthorized — please login again.';
    if (msg.contains('403')) {
      return 'Permission denied — admin access required.';
    }
    if (msg.contains('404')) return 'Driver not found.';
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
        title: const Text('Drivers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDrivers,
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDriver,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Driver'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),

      body: FutureBuilder<List<DriverModel>>(
        future: _driversFuture,

        builder: (context, snapshot) {
          // ── Loading ──────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Error ────────────────────────────────────────────────────
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
                      'Failed to load drivers',
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
                      onPressed: _loadDrivers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final drivers = snapshot.data ?? [];

          // ── Empty state ──────────────────────────────────────────────
          if (drivers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 80,
                    color: Colors.grey[350],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Drivers Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add Driver" below to get started.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // ── Driver list ──────────────────────────────────────────────
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];

              return DriverCard(
                driver: driver,
                onEdit: () => _openEditDriver(driver),
                onDelete: () => _confirmDelete(driver),
              );
            },
          );
        },
      ),
    );
  }
}
