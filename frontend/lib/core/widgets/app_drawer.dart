import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../storage/token_storage.dart';
import '../../modules/auth/services/auth_service.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/vehicle/screens/vehicle_screen.dart';
import '../../modules/driver/screens/driver_screen.dart';
import '../../modules/route/screens/route_screen.dart';
import '../../modules/trip/screens/trip_screen.dart';
import '../../modules/allocation/screens/allocation_screen.dart';
import '../../modules/attendance/screens/attendance_screen.dart';
import '../../modules/maintenance/screens/maintenance_screen.dart';
import '../../modules/fuel/screens/fuel_screen.dart';
import '../../modules/document/screens/document_screen.dart';
import '../../modules/user/screens/user_screen.dart';

// Phase 3: RBAC role constants matching backend Role.name values
class _Role {
  static const superAdmin = 'SUPER_ADMIN';
  static const manager   = 'MANAGER';
  static const supervisor = 'SUPERVISOR';
  static const driver    = 'DRIVER';

  /// Roles that may view and manage Master Data (Vehicles, Drivers, Routes).
  static const masterDataRoles = {superAdmin, manager};

  /// Roles that may access Shift Allocation.
  static const allocationRoles = {superAdmin, manager, supervisor};

  /// All roles may access Attendance (DRIVER sees own; SUPERVISOR+ sees all).
  static const attendanceRoles = {superAdmin, manager, supervisor, driver};
}

/// Navigation drawer used across the app.
///
/// Phase 3: Converted to StatefulWidget to load role from secure storage
/// and apply RBAC-based menu visibility:
///   DRIVER     → Dashboard, Trips
///   SUPERVISOR → Dashboard, Trips, Shift Allocation
///   MANAGER    → all items
///   SUPER_ADMIN → all items
class AppDrawer extends StatefulWidget {
  /// The route name of the currently active screen (e.g. 'dashboard', 'trips').
  final String activeRoute;

  const AppDrawer({super.key, required this.activeRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? _roleName;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await TokenStorage.getRole();
    if (mounted) setState(() => _roleName = role);
  }

  bool get _canViewAllocation =>
      _roleName == null || _Role.allocationRoles.contains(_roleName);

  bool get _canViewMasterData =>
      _roleName == null || _Role.masterDataRoles.contains(_roleName);

  bool get _canViewAttendance =>
      _roleName == null || _Role.attendanceRoles.contains(_roleName);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      width: 272,
      child: SafeArea(
        child: Column(
          children: [
            // ── Brand header ───────────────────────────────────────────────
            _BrandHeader(roleName: _roleName),

            const SizedBox(height: 8),

            // ── Navigation items ───────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                children: [
                  _SectionLabel('Operations'),
                  _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    routeKey: 'dashboard',
                    activeRoute: widget.activeRoute,
                    onTap: () => _navigateTo(context, 'dashboard', null),
                  ),
                  _NavItem(
                    icon: Icons.local_shipping_rounded,
                    label: 'Trips',
                    routeKey: 'trips',
                    activeRoute: widget.activeRoute,
                    onTap: () => _navigateTo(
                      context, 'trips', const TripScreen(),
                    ),
                  ),

                  // All roles — DRIVER sees own; SUPERVISOR+ sees company
                  if (_canViewAttendance)
                    _NavItem(
                      icon: Icons.fact_check_rounded,
                      label: 'Attendance',
                      routeKey: 'attendance',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'attendance', const AttendanceScreen(),
                      ),
                    ),

                  // SUPERVISOR and above only
                  if (_canViewAllocation)
                    _NavItem(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Shift Allocation',
                      routeKey: 'allocation',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'allocation', const AllocationScreen(),
                      ),
                    ),

                  // MANAGER and above only
                  if (_canViewMasterData) ...[\
                    const SizedBox(height: 8),
                    _SectionLabel('Master Data'),
                    _NavItem(
                      icon: Icons.fire_truck_rounded,
                      label: 'Vehicles',
                      routeKey: 'vehicles',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'vehicles', const VehicleScreen(),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.people_rounded,
                      label: 'Drivers',
                      routeKey: 'drivers',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'drivers', const DriverScreen(),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.route_rounded,
                      label: 'Routes',
                      routeKey: 'routes',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'routes', const RouteScreen(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SectionLabel('Enterprise'),
                    _NavItem(
                      icon: Icons.build_circle_rounded,
                      label: 'Maintenance',
                      routeKey: 'maintenance',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'maintenance', const MaintenanceScreen(),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.local_gas_station_rounded,
                      label: 'Fuel',
                      routeKey: 'fuel',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'fuel', const FuelScreen(),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.folder_rounded,
                      label: 'Documents',
                      routeKey: 'documents',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'documents', const DocumentScreen(),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.manage_accounts_rounded,
                      label: 'Users',
                      routeKey: 'users',
                      activeRoute: widget.activeRoute,
                      onTap: () => _navigateTo(
                        context, 'users', const UserScreen(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Divider ────────────────────────────────────────────────────
            const Divider(color: Color(0xFF1E293B), height: 1),

            // ── Logout ─────────────────────────────────────────────────────
            _LogoutTile(),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeKey, Widget? screen) {
    Navigator.pop(context); // close drawer

    if (routeKey == widget.activeRoute) return; // already here

    if (screen == null) {
      // Pop back to dashboard (root)
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ─── Brand header ─────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  final String? roleName;
  const _BrandHeader({this.roleName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo mark
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tipper ERP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Fleet Management System',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
          // Phase 3: show role badge when available
          if (roleName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleName!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.sidebarIcon,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ─── Nav item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String routeKey;
  final String activeRoute;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.routeKey,
    required this.activeRoute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = routeKey == activeRoute;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive
            ? AppColors.sidebarActive.withValues(alpha: 0.9)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? AppColors.sidebarIconActive
                      : AppColors.sidebarIcon,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.sidebarTextActive
                        : AppColors.sidebarText,
                    fontSize: 14,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logout tile ──────────────────────────────────────────────────────────────

class _LogoutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: () => _logout(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          splashColor: AppColors.error.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    Navigator.pop(context); // close drawer first

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of Tipper ERP?',
        ),
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

    if (confirmed != true) return;
    if (!context.mounted) return;

    await AuthService().logout(); // Phase 3: clears token + role via clearAll()

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
