import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../modules/auth/services/auth_service.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/vehicle/screens/vehicle_screen.dart';
import '../../modules/driver/screens/driver_screen.dart';
import '../../modules/route/screens/route_screen.dart';
import '../../modules/trip/screens/trip_screen.dart';
import '../../modules/allocation/screens/allocation_screen.dart';

/// Navigation drawer used across the app.
///
/// Displays the Tipper ERP brand header, a user profile section,
/// module navigation links, and a logout action.
class AppDrawer extends StatelessWidget {
  /// The route name of the currently active screen, used to highlight
  /// the correct menu item. Pass a simple string like `'dashboard'`,
  /// `'vehicles'`, `'drivers'`, etc.
  final String activeRoute;

  const AppDrawer({super.key, required this.activeRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      width: 272,
      child: SafeArea(
        child: Column(
          children: [
            // ── Brand header ───────────────────────────────────────────────
            _BrandHeader(),

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
                    activeRoute: activeRoute,
                    onTap: () => _navigateTo(
                      context,
                      'dashboard',
                      // Dashboard is the root; just close the drawer.
                      null,
                    ),
                  ),
                  _NavItem(
                    icon: Icons.local_shipping_rounded,
                    label: 'Trips',
                    routeKey: 'trips',
                    activeRoute: activeRoute,
                    onTap: () => _navigateTo(
                      context,
                      'trips',
                      const TripScreen(),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Shift Allocation',
                    routeKey: 'allocation',
                    activeRoute: activeRoute,
                    onTap: () => _navigateTo(
                      context,
                      'allocation',
                      const AllocationScreen(),
                    ),
                  ),

                  const SizedBox(height: 8),
                  _SectionLabel('Master Data'),
                  _NavItem(
                    icon: Icons.fire_truck_rounded,
                    label: 'Vehicles',
                    routeKey: 'vehicles',
                    activeRoute: activeRoute,
                    onTap: () => _navigateTo(
                      context,
                      'vehicles',
                      const VehicleScreen(),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.people_rounded,
                    label: 'Drivers',
                    routeKey: 'drivers',
                    activeRoute: activeRoute,
                    onTap: () => _navigateTo(
                      context,
                      'drivers',
                      const DriverScreen(),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.route_rounded,
                    label: 'Routes',
                    routeKey: 'routes',
                    activeRoute: activeRoute,
                    onTap: () => _navigateTo(
                      context,
                      'routes',
                      const RouteScreen(),
                    ),
                  ),
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

    if (routeKey == activeRoute) return; // already here

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

    await AuthService().logout();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
