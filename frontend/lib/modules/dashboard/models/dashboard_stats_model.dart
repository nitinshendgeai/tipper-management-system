/// Maps to GET /dashboard/stats — full operational fleet analytics.
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
    required this.tripsTotal,
    required this.tripsCreated,
    required this.tripsActive,
    required this.tripsCompleted,
    required this.tripsCancelled,
    required this.totalRevenue,
    required this.totalDieselUsed,
    required this.totalTripExpenses,
    required this.utilisationPct,
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

      tripsTotal: json['trips_total'] as int? ?? 0,
      tripsCreated: json['trips_created'] as int? ?? 0,
      tripsActive: json['trips_active'] as int? ?? 0,
      tripsCompleted: json['trips_completed'] as int? ?? 0,
      tripsCancelled: json['trips_cancelled'] as int? ?? 0,

      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalDieselUsed: (json['total_diesel_used'] as num?)?.toDouble() ?? 0.0,
      totalTripExpenses:
          (json['total_trip_expenses'] as num?)?.toDouble() ?? 0.0,

      utilisationPct: (json['utilisation_pct'] as num?)?.toDouble() ?? 0.0,
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
