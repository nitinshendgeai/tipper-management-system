/// Maps to GET /dashboard/stats — full operational fleet analytics.
/// Phase 5: extended with today-scoped and month-scoped KPI fields.
class DashboardStatsModel {
  // Master counts
  final int totalVehicles;
  final int totalDrivers;
  final int totalRoutes;

  // Fleet status
  final int vehiclesAvailable;
  final int vehiclesAssigned;
  final int vehiclesOnTrip;
  final int vehiclesMaintenance;

  final int driversAvailable;
  final int driversOnTrip;
  final int driversOffDuty;
  final int driversOnDuty; // punched in today, shift still active

  // Trip lifecycle
  final int tripsTotal;
  final int tripsCreated;
  final int tripsActive;
  final int tripsCompleted;
  final int tripsCancelled;

  // Financial
  final double totalRevenue;
  final double totalDieselUsed;
  final double totalTripExpenses;

  // Utilisation
  final double utilisationPct;

  // ── Phase 5: Today-scoped KPIs ─────────────────────────────────────────────
  final int tripsToday;           // total trips created/active today
  final int tripsCompletedToday;  // trips completed today
  final double revenueToday;      // revenue from completed trips today
  final double revenueThisMonth;  // revenue from completed trips this month

  // ── Phase 5: Rate + average KPIs ──────────────────────────────────────────
  final double tripCompletionRate; // completed / total * 100 (all-time)
  final double avgRevenuePerTrip;  // avg revenue per completed trip (all-time)
  final double avgDieselPerTrip;   // avg diesel (litres) per completed trip

  // Computed helpers
  double get netRevenue => totalRevenue - totalDieselUsed - totalTripExpenses;

  const DashboardStatsModel({
    required this.totalVehicles,
    required this.totalDrivers,
    required this.totalRoutes,
    required this.vehiclesAvailable,
    required this.vehiclesAssigned,
    required this.vehiclesOnTrip,
    required this.vehiclesMaintenance,
    required this.driversAvailable,
    required this.driversOnTrip,
    required this.driversOffDuty,
    required this.driversOnDuty,
    required this.tripsTotal,
    required this.tripsCreated,
    required this.tripsActive,
    required this.tripsCompleted,
    required this.tripsCancelled,
    required this.totalRevenue,
    required this.totalDieselUsed,
    required this.totalTripExpenses,
    required this.utilisationPct,
    // Phase 5 optional — default to 0 if server doesn't return them
    this.tripsToday = 0,
    this.tripsCompletedToday = 0,
    this.revenueToday = 0.0,
    this.revenueThisMonth = 0.0,
    this.tripCompletionRate = 0.0,
    this.avgRevenuePerTrip = 0.0,
    this.avgDieselPerTrip = 0.0,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalVehicles: json['total_vehicles'] as int? ?? 0,
      totalDrivers: json['total_drivers'] as int? ?? 0,
      totalRoutes: json['total_routes'] as int? ?? 0,

      vehiclesAvailable: json['vehicles_available'] as int? ?? 0,
      vehiclesAssigned: json['vehicles_assigned'] as int? ?? 0,
      vehiclesOnTrip: json['vehicles_on_trip'] as int? ?? 0,
      vehiclesMaintenance: json['vehicles_maintenance'] as int? ?? 0,

      driversAvailable: json['drivers_available'] as int? ?? 0,
      driversOnTrip: json['drivers_on_trip'] as int? ?? 0,
      driversOffDuty: json['drivers_off_duty'] as int? ?? 0,
      driversOnDuty: json['drivers_on_duty'] as int? ?? 0,

      tripsTotal: json['trips_total'] as int? ?? 0,
      tripsCreated: json['trips_created'] as int? ?? 0,
      tripsActive: json['trips_active'] as int? ?? 0,
      tripsCompleted: json['trips_completed'] as int? ?? 0,
      tripsCancelled: json['trips_cancelled'] as int? ?? 0,

      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalDieselUsed:
          (json['total_diesel_used'] as num?)?.toDouble() ?? 0.0,
      totalTripExpenses:
          (json['total_trip_expenses'] as num?)?.toDouble() ?? 0.0,

      utilisationPct: (json['utilisation_pct'] as num?)?.toDouble() ?? 0.0,

      // Phase 5 fields — safe defaults if old backend / offline
      tripsToday: json['trips_today'] as int? ?? 0,
      tripsCompletedToday: json['trips_completed_today'] as int? ?? 0,
      revenueToday:
          (json['revenue_today'] as num?)?.toDouble() ?? 0.0,
      revenueThisMonth:
          (json['revenue_this_month'] as num?)?.toDouble() ?? 0.0,
      tripCompletionRate:
          (json['trip_completion_rate'] as num?)?.toDouble() ?? 0.0,
      avgRevenuePerTrip:
          (json['avg_revenue_per_trip'] as num?)?.toDouble() ?? 0.0,
      avgDieselPerTrip:
          (json['avg_diesel_per_trip'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory DashboardStatsModel.empty() => const DashboardStatsModel(
        totalVehicles: 0,
        totalDrivers: 0,
        totalRoutes: 0,
        vehiclesAvailable: 0,
        vehiclesAssigned: 0,
        vehiclesOnTrip: 0,
        vehiclesMaintenance: 0,
        driversAvailable: 0,
        driversOnTrip: 0,
        driversOffDuty: 0,
        driversOnDuty: 0,
        tripsTotal: 0,
        tripsCreated: 0,
        tripsActive: 0,
        tripsCompleted: 0,
        tripsCancelled: 0,
        totalRevenue: 0.0,
        totalDieselUsed: 0.0,
        totalTripExpenses: 0.0,
        utilisationPct: 0.0,
      );
}
