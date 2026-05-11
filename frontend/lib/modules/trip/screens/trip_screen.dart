import 'package:flutter/material.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../widgets/trip_card.dart';
import 'create_trip_screen.dart';
import 'complete_trip_screen.dart';
import 'trip_detail_screen.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen>
    with SingleTickerProviderStateMixin {
  final TripService _tripService = TripService();

  late TabController _tabController;

  late Future<List<TripModel>> _allFuture;
  late Future<List<TripModel>> _activeFuture;
  late Future<List<TripModel>> _completedFuture;
  late Future<List<TripModel>> _cancelledFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    setState(() {
      _allFuture = _tripService.getTrips();

      // Active = CREATED + STARTED
      _activeFuture =
          Future.wait([
            _tripService.getTrips(status: 'CREATED'),
            _tripService.getTrips(status: 'STARTED'),
          ]).then(
            (results) => [...results[0], ...results[1]]
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                  a.createdAt ?? DateTime(0),
                ),
              ),
          );

      _completedFuture = _tripService.getTrips(status: 'COMPLETED');
      _cancelledFuture = _tripService.getTrips(status: 'CANCELLED');
    });
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  Future<void> _openCreate() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateTripScreen()),
    );
    if (result == true) _loadAll();
  }

  Future<void> _openDetail(TripModel trip) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
    );
    if (result == true) _loadAll();
  }

  Future<void> _openComplete(TripModel trip) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CompleteTripScreen(trip: trip)),
    );
    if (result == true) _loadAll();
  }

  // ─── Start trip dialog ────────────────────────────────────────────────────

  Future<void> _confirmStart(TripModel trip) async {
    final kmController = TextEditingController(
      text: trip.startKm?.toStringAsFixed(0) ?? '',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Start Trip'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${trip.vehicleNumber}  •  ${trip.sourceLocation ?? ''}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Start KM *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('START'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final km = double.tryParse(kmController.text.trim());
    if (km == null || km <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid Start KM'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await _tripService.startTrip(trip.id, km);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip #${trip.id} started!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _parseError(Object e, String fallback) {
    final msg = e.toString();
    if (msg.contains('401')) return 'Unauthorized — please login again.';
    if (msg.contains('403')) return 'Permission denied.';
    if (msg.contains('409')) return 'Conflict — check trip status.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server.';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_road),
        label: const Text('New Trip'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(
            future: _allFuture,
            showActions: true,
            empty: 'No trips yet.\nTap "New Trip" to start.',
          ),
          _buildList(
            future: _activeFuture,
            showActions: true,
            empty: 'No active trips.',
          ),
          _buildList(
            future: _completedFuture,
            showActions: false,
            empty: 'No completed trips yet.',
          ),
          _buildList(
            future: _cancelledFuture,
            showActions: false,
            empty: 'No cancelled trips.',
          ),
        ],
      ),
    );
  }

  Widget _buildList({
    required Future<List<TripModel>> future,
    required bool showActions,
    required String empty,
  }) {
    return FutureBuilder<List<TripModel>>(
      future: future,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load trips',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _parseError(snapshot.error!, 'Unknown error'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final trips = snapshot.data ?? [];

        if (trips.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 80,
                  color: Colors.grey[350],
                ),
                const SizedBox(height: 16),
                Text(
                  empty,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadAll(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: trips.length,
            itemBuilder: (ctx, i) {
              final trip = trips[i];
              return TripCard(
                trip: trip,
                onTap: () => _openDetail(trip),
                onStart: showActions && trip.isCreated
                    ? () => _confirmStart(trip)
                    : null,
                onComplete: showActions && trip.isStarted
                    ? () => _openComplete(trip)
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}
