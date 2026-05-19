"""
Analytics schemas — Phase 5: Analytics + Dashboard Intelligence + AI Foundation.

These schemas form the structured data contracts for:
  - Operational KPI endpoints
  - Fleet intelligence
  - Driver performance
  - Alert foundation
  - AI-ready data export

All response schemas are designed to be AI-parseable — clean field names,
typed values, no nested nulls — so future ML services can consume them
without transformation.
"""

from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel


# ─── Time Window ──────────────────────────────────────────────────────────────

class TimeWindow(BaseModel):
    """Describes the period covered by an analytics response."""
    period: str          # "today" | "week" | "month" | "last_30_days"
    from_date: date
    to_date: date


# ─── Operational KPIs ────────────────────────────────────────────────────────

class OperationalKPIs(BaseModel):
    """
    Time-windowed operational metrics — MANAGER / SUPER_ADMIN view.

    AI use: trip volume forecasting, operational anomaly detection.
    """
    window: TimeWindow

    # Trip volumes
    trips_created: int
    trips_started: int
    trips_completed: int
    trips_cancelled: int
    trip_completion_rate: float     # completed / (created) * 100

    # Financial
    total_revenue: float
    total_diesel_expense: float
    total_trip_expenses: float
    net_revenue: float              # revenue - diesel - expenses
    avg_revenue_per_trip: float
    avg_expense_per_trip: float

    # Distance / fuel
    total_distance_km: float
    total_diesel_litres: float
    avg_fuel_efficiency_km_per_litre: float

    # Attendance
    total_driver_shifts: int        # unique drivers who punched in


# ─── Fleet Analytics ─────────────────────────────────────────────────────────

class VehicleUtilization(BaseModel):
    """Per-vehicle utilization stats — AI use: maintenance prediction, idle detection."""
    vehicle_id: int
    vehicle_number: str
    vehicle_type: str
    total_trips: int
    total_distance_km: float
    total_revenue: float
    total_diesel_used: float
    avg_trip_distance_km: float
    current_status: str             # AVAILABLE | ASSIGNED | ON_TRIP | MAINTENANCE


class FleetAnalytics(BaseModel):
    """
    Fleet-level utilization report — MANAGER / SUPER_ADMIN.

    AI use: vehicle utilization scoring, idle vehicle detection,
    maintenance scheduling prediction.
    """
    window: TimeWindow
    total_vehicles: int
    active_vehicles: int            # AVAILABLE + ASSIGNED + ON_TRIP
    utilisation_pct: float          # ON_TRIP / active * 100
    avg_trips_per_vehicle: float
    top_vehicles: list[VehicleUtilization]     # all vehicles, sorted by trips desc


# ─── Driver Analytics ─────────────────────────────────────────────────────────

class DriverPerformance(BaseModel):
    """
    Per-driver performance summary.

    AI use: driver scoring, fatigue detection, incentive calculation.
    """
    window: TimeWindow
    driver_id: int
    driver_name: str
    total_trips: int
    trips_completed: int
    trips_cancelled: int
    completion_rate: float
    total_distance_km: float
    total_revenue_generated: float
    total_expenses_logged: float
    avg_revenue_per_trip: float
    total_shifts: int               # attendance punch-ins in window
    current_status: str             # OFF_DUTY | AVAILABLE | ON_TRIP | BREAK


# ─── Supervisor Dashboard ─────────────────────────────────────────────────────

class SupervisorSnapshot(BaseModel):
    """
    Operational snapshot for SUPERVISOR role — focused on shift status.
    """
    today: date
    drivers_on_duty: int
    drivers_off_duty: int
    drivers_on_trip: int
    active_assignments: int
    trips_created_today: int
    trips_started_today: int
    trips_completed_today: int
    pending_trips: int              # CREATED status


# ─── Driver Self-Stats ────────────────────────────────────────────────────────

class DriverSelfStats(BaseModel):
    """
    Personal stats for DRIVER role — their own performance window.

    AI use: driver self-coaching, performance badges.
    """
    window: TimeWindow
    driver_name: str
    total_trips: int
    trips_completed: int
    trips_cancelled: int
    total_distance_km: float
    total_revenue_generated: float
    total_expenses_logged: float
    total_shifts: int
    current_status: str
    # Today's attendance
    punched_in_today: bool
    punch_in_time: Optional[datetime] = None


# ─── Smart Alerts ────────────────────────────────────────────────────────────

class AlertSeverity:
    CRITICAL = "CRITICAL"
    HIGH     = "HIGH"
    MEDIUM   = "MEDIUM"
    LOW      = "LOW"


class AlertType:
    OVERDUE_TRIP        = "OVERDUE_TRIP"
    EXCESSIVE_EXPENSE   = "EXCESSIVE_EXPENSE"
    LOW_ATTENDANCE      = "LOW_ATTENDANCE"
    INACTIVE_VEHICLE    = "INACTIVE_VEHICLE"
    INACTIVE_DRIVER     = "INACTIVE_DRIVER"
    DELAYED_TRIP        = "DELAYED_TRIP"
    HIGH_CANCELLATION   = "HIGH_CANCELLATION"


class OperationalAlert(BaseModel):
    """
    Structured operational alert.

    AI use: anomaly detection training data, alert prioritization.
    Future: push notification payload, Slack/email webhook body.
    """
    alert_type: str         # AlertType constant
    severity: str           # AlertSeverity constant
    title: str
    message: str
    entity_type: str        # "trip" | "vehicle" | "driver" | "fleet"
    entity_id: Optional[int] = None
    entity_label: Optional[str] = None     # e.g. vehicle number, driver name
    triggered_at: datetime


class AlertsResponse(BaseModel):
    """Response from GET /analytics/alerts."""
    total_alerts: int
    critical_count: int
    high_count: int
    alerts: list[OperationalAlert]
