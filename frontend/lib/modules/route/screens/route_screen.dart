import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/route_service.dart';
import '../widgets/route_card.dart';
import 'add_route_screen.dart';
import 'edit_route_screen.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final RouteService _routeService = RouteService();

  late Future<List<RouteModel>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  void _loadRoutes() {
    setState(() {
      _routesFuture = _routeService.getRoutes();
    });
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  Future<void> _openAddRoute() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddRouteScreen()),
    );

    if (result == true) _loadRoutes();
  }

  Future<void> _openEditRoute(RouteModel route) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditRouteScreen(route: route)),
    );

    if (result == true) _loadRoutes();
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(RouteModel route) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Route'),
          ],
        ),
        content: Text(
          'Delete route\n"${route.sourceLocation} → ${route.destinationLocation}"?\n\nThis action cannot be undone.',
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

    if (confirmed == true) await _deleteRoute(route);
  }

  Future<void> _deleteRoute(RouteModel route) async {
    try {
      await _routeService.deleteRoute(route.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${route.sourceLocation} → ${route.destinationLocation} deleted',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadRoutes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e, 'Failed to delete route')),
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
    if (msg.contains('404')) return 'Route not found.';
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
        title: const Text('Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRoutes,
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddRoute,
        icon: const Icon(Icons.add_road),
        label: const Text('Add Route'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),

      body: FutureBuilder<List<RouteModel>>(
        future: _routesFuture,

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
                      'Failed to load routes',
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
                      onPressed: _loadRoutes,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final routes = snapshot.data ?? [];

          // ── Empty state ──────────────────────────────────────────────
          if (routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route_outlined, size: 80, color: Colors.grey[350]),
                  const SizedBox(height: 16),
                  Text(
                    'No Routes Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add Route" below to get started.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // ── Route list ───────────────────────────────────────────────
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];

              return RouteCard(
                route: route,
                onEdit: () => _openEditRoute(route),
                onDelete: () => _confirmDelete(route),
              );
            },
          );
        },
      ),
    );
  }
}
