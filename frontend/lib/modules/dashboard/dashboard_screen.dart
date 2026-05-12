import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_drawer.dart';
import '../vehicle/screens/vehicle_screen.dart';
import '../driver/screens/driver_screen.dart';
import '../route/screens/route_screen.dart';
import '../trip/screens/trip_screen.dart';
import '../allocation/screens/allocation_screen.dart';
import '../auth/services/auth_service.dart';
import '../auth/screens/login_screen.dart';

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

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of Tipper ERP?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await AuthService().logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,

      // ── Sidebar drawer ─────────────────────────────────────────────────────
      drawer: const AppDrawer(activeRoute: 'dashboard'),

      // ── App bar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(Icons.local_shipping_rounded, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Tipper ERP',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Dashboard',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh data',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Body ───────────────────────────────────────────────────────────────
      body: FutureBuilder<DashboardStatsModel>(
        future: _statsFuture,
        builder: (ctx, snapshot) {
          final stats = snapshot.data ?? DashboardStatsModel.empty();
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError && !loading;

          return RefreshIndicator(
            onRefresh: () async => _loadStats(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Welcome header ───────────────────────────────────────
                  _WelcomeHeader(isLoading: loading),

                  const SizedBox(height: 20),

                  // ── Error banner ─────────────────────────────────────────
                  if (hasError) ...[
                    _errorBanner(),
                    const SizedBox(height: 16),
                  ],

                  // ── Fleet Status Row ─────────────────────────────────────
                  _sectionLabel('Fleet Status'),
                  const SizedBox(height: 10),
                  _fleetStatusRow(stats, loading),

                  const SizedBox(height: 24),

                  // ── Section: Master Data ─────────────────────────────────
                  _sectionLabel('Master Data'),
                  const SizedBox(height: 10),
                  _twoColGrid([
                    _DashCard(
                      title: 'Vehicles',
                      value: stats.totalVehicles.toString(),
                      icon: Icons.fire_truck_rounded,
                      color: const Color(0xFF1E40AF),
                      isLoading: loading,
                      onTap: () => _goTo(const VehicleScreen()),
                    ),
                    _DashCard(
                      title: 'Drivers',
                      value: stats.totalDrivers.toString(),
                      icon: Icons.people_rounded,
                      color: const Color(0xFF4338CA),
                      isLoading: loading,
                      onTap: () => _goTo(const DriverScreen()),
                    ),
                    _DashCard(
                      title: 'Routes',
                      value: stats.totalRoutes.toString(),
                      icon: Icons.route_rounded,
                      color: const Color(0xFF0891B2),
                      isLoading: loading,
                      onTap: () => _goTo(const RouteScreen()),
                    ),
                    _DashCard(
                      title: 'Active Shifts',
                      value: stats.vehiclesAssigned.toString(),
                      icon: Icons.swap_horiz_rounded,
                      color: const Color(0xFF7C3AED),
                      isLoading: loading,
                      onTap: () => _goTo(const AllocationScreen()),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── Section: Live Operations ─────────────────────────────
                  _sectionLabel('Live Operations'),
                  const SizedBox(height: 10),
                  _twoColGrid([
                    _DashCard(
                      title: 'On Trip',
                      value: stats.vehiclesOnTrip.toString(),
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFFD97706),
                      isLoading: loading,
                      onTap: () => _goTo(const TripScreen()),
                    ),
                    _DashCard(
                      title: 'Trips Today',
                      value: stats.tripsActive.toString(),
                      icon: Icons.directions_car_rounded,
                      color: const Color(0xFFEA580C),
                      isLoading: loading,
                      onTap: () => _goTo(const TripScreen()),
                    ),
                    _DashCard(
                      title: 'Completed',
                      value: stats.tripsCompleted.toString(),
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF16A34A),
                      isLoading: loading,
                      onTap: () => _goTo(const TripScreen()),
                    ),
                    _DashCard(
                      title: 'Pending Start',
                      value: stats.tripsCreated.toString(),
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFF475569),
                      isLoading: loading,
                      onTap: () => _goTo(const TripScreen()),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── Section: Financials ──────────────────────────────────
                  _sectionLabel('Financial Analytics'),
                  const SizedBox(height: 10),
                  _twoColGrid([
                    _DashCard(
                      title: 'Revenue',
                      value: '₹${_fmt(stats.totalRevenue)}',
                      icon: Icons.currency_rupee_rounded,
                      color: const Color(0xFF15803D),
                      isLoading: loading,
                      onTap: () => _goTo(const TripScreen()),
                    ),
                    _DashCard(
                      title: 'Expenses',
                      value: '₹${_fmt(stats.totalTripExpenses)}',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFFDC2626),
                      isLoading: loading,
                      onTap: () => _goTo(const TripScreen()),
                    ),
                    _DashCard(
                      title: 'Diesel Used',
                      value: '${_fmt(stats.totalDieselUsed)} L',
                      icon: Icons.local_gas_station_rounded,
                      color: const Color(0xFFB45309),
                      isLoading: loading,
                      onTap: () => _goTo(const TripScreen()),
                    ),
                    _DashCard(
                      title: 'Utilisation',
                      value: '${stats.utilisationPct.toStringAsFixed(0)}%',
                      icon: Icons.speed_rounded,
                      color: const Color(0xFF0E7490),
                      isLoading: loading,
                      onTap: () => _goTo(const TripScreen()),
                    ),
                  ]),
                ],
              ),
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
        _statusPill('Available', stats.vehiclesAvailable, AppColors.success, loading),
        const SizedBox(width: 8),
        _statusPill('Assigned', stats.vehiclesAssigned, AppColors.primary, loading),
        const SizedBox(width: 8),
        _statusPill('On Trip', stats.vehiclesOnTrip, AppColors.warning, loading),
        const SizedBox(width: 8),
        _statusPill('Maintenance', stats.vehiclesMaintenance, AppColors.error, loading),
      ],
    );
  }

  Widget _statusPill(String label, int count, Color color, bool loading) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.25)),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: color,
                    ),
                  ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load live data — showing cached values.',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _loadStats,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.3,
      ),
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

// ─── Welcome header ───────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  final bool isLoading;
  const _WelcomeHeader({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Fleet Operations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLoading ? 'Syncing data…' : 'Live data',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
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
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        splashColor: Colors.white.withValues(alpha: 0.15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 12),
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
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
