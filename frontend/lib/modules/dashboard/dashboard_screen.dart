import 'package:flutter/material.dart';

import '../vehicle/screens/vehicle_screen.dart';
import '../driver/screens/driver_screen.dart';
import '../route/screens/route_screen.dart';
import '../trip/screens/trip_screen.dart';
import '../allocation/screens/allocation_screen.dart';

import 'models/dashboard_stats_model.dart';
import 'services/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  late Future<DashboardStatsModel> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() => _statsFuture = _dashboardService.getStats());
  }

  Future<void> _goTo(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Operations Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        ],
      ),
      body: FutureBuilder<DashboardStatsModel>(
        future: _statsFuture,
        builder: (ctx, snapshot) {
          final stats = snapshot.data ?? DashboardStatsModel.empty();
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError && !loading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Error banner ───────────────────────────────────────────
                if (hasError) _errorBanner(),

                // ── Fleet Status Row ───────────────────────────────────────
                _sectionLabel('Fleet Status'),
                const SizedBox(height: 10),
                _fleetStatusRow(stats, loading),

                const SizedBox(height: 20),

                // ── Section: Master Data ───────────────────────────────────
                _sectionLabel('Master Data'),
                const SizedBox(height: 10),
                _twoColGrid([
                  _DashCard(
                    title: 'Vehicles',
                    value: stats.totalVehicles.toString(),
                    icon: Icons.fire_truck,
                    color: Colors.blue,
                    isLoading: loading,
                    onTap: () => _goTo(const VehicleScreen()),
                  ),
                  _DashCard(
                    title: 'Drivers',
                    value: stats.totalDrivers.toString(),
                    icon: Icons.people,
                    color: Colors.indigo,
                    isLoading: loading,
                    onTap: () => _goTo(const DriverScreen()),
                  ),
                  _DashCard(
                    title: 'Routes',
                    value: stats.totalRoutes.toString(),
                    icon: Icons.route,
                    color: Colors.teal,
                    isLoading: loading,
                    onTap: () => _goTo(const RouteScreen()),
                  ),
                  _DashCard(
                    title: 'Shifts Active',
                    value: stats.vehiclesAssigned.toString(),
                    icon: Icons.swap_horiz_rounded,
                    color: Colors.purple,
                    isLoading: loading,
                    onTap: () => _goTo(const AllocationScreen()),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Section: Live Operations ───────────────────────────────
                _sectionLabel('Live Operations'),
                const SizedBox(height: 10),
                _twoColGrid([
                  _DashCard(
                    title: 'On Trip',
                    value: stats.vehiclesOnTrip.toString(),
                    icon: Icons.local_shipping,
                    color: Colors.orange,
                    isLoading: loading,
                    onTap: () => _goTo(const TripScreen()),
                  ),
                  _DashCard(
                    title: 'Trips Today',
                    value: stats.tripsActive.toString(),
                    icon: Icons.directions_car,
                    color: Colors.deepOrange,
                    isLoading: loading,
                    onTap: () => _goTo(const TripScreen()),
                  ),
                  _DashCard(
                    title: 'Completed',
                    value: stats.tripsCompleted.toString(),
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    isLoading: loading,
                    onTap: () => _goTo(const TripScreen()),
                  ),
                  _DashCard(
                    title: 'Pending Start',
                    value: stats.tripsCreated.toString(),
                    icon: Icons.schedule,
                    color: Colors.blueGrey,
                    isLoading: loading,
                    onTap: () => _goTo(const TripScreen()),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Section: Financials ────────────────────────────────────
                _sectionLabel('Financial Analytics'),
                const SizedBox(height: 10),
                _twoColGrid([
                  _DashCard(
                    title: 'Revenue',
                    value: '₹${_fmt(stats.totalRevenue)}',
                    icon: Icons.currency_rupee,
                    color: Colors.green.shade700,
                    isLoading: loading,
                    onTap: () => _goTo(const TripScreen()),
                  ),
                  _DashCard(
                    title: 'Expenses',
                    value: '₹${_fmt(stats.totalTripExpenses)}',
                    icon: Icons.receipt_outlined,
                    color: Colors.red.shade600,
                    isLoading: loading,
                    onTap: () => _goTo(const TripScreen()),
                  ),
                  _DashCard(
                    title: 'Diesel Used',
                    value: '${_fmt(stats.totalDieselUsed)} L',
                    icon: Icons.local_gas_station_outlined,
                    color: Colors.amber.shade800,
                    isLoading: loading,
                    onTap: () => _goTo(const TripScreen()),
                  ),
                  _DashCard(
                    title: 'Utilisation',
                    value: '${stats.utilisationPct.toStringAsFixed(0)}%',
                    icon: Icons.speed_outlined,
                    color: Colors.cyan.shade700,
                    isLoading: loading,
                    onTap: () => _goTo(const TripScreen()),
                  ),
                ]),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Fleet status row ─────────────────────────────────────────────────────

  Widget _fleetStatusRow(DashboardStatsModel stats, bool loading) {
    return Row(
      children: [
        _statusPill(
          'Available',
          stats.vehiclesAvailable,
          Colors.green,
          loading,
        ),
        const SizedBox(width: 8),
        _statusPill('Assigned', stats.vehiclesAssigned, Colors.blue, loading),
        const SizedBox(width: 8),
        _statusPill('On Trip', stats.vehiclesOnTrip, Colors.orange, loading),
        const SizedBox(width: 8),
        _statusPill(
          'Maintenance',
          stats.vehiclesMaintenance,
          Colors.red,
          loading,
        ),
      ],
    );
  }

  Widget _statusPill(String label, int count, Color color, bool loading) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Text(
                    count.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: color,
                    ),
                  ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error banner ─────────────────────────────────────────────────────────

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load live data — showing cached values.',
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ),
          TextButton(onPressed: _loadStats, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.grey[600],
      letterSpacing: 1.2,
    ),
  );

  Widget _twoColGrid(List<Widget> children) => GridView.count(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: children,
  );

  String _fmt(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _DashCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 10),
            isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
