from pydantic import BaseModel
from typing import Optional


class DashboardStats(BaseModel):
    """
    Operational fleet analytics for the ERP dashboard.
    Phase 5: extended with today-scoped and month-scoped KPIs.
    AI-ready: all fields needed for anomaly detection, utilisation analysis.

    Backward-compatible: new Phase 5 fields are Optional with defaults
    so older clients (Flutter) that don't yet parse them won't break.
    """

    # ── Master counts ──────────────────────────────────────────────────────────
    total_vehicles: int
    total_drivers: int
    total_routes: int

    # ── Fleet status ───────────────────────────────────────────────────────────
    vehicles_available: int
    vehicles_assigned: int
    vehicles_on_trip: int
    vehicles_maintenance: int

    drivers_available: int      # on shift, not on trip
    drivers_on_trip: int
    drivers_off_duty: int

    # ── Attendance (today) ─────────────────────────────────────────────────────
    drivers_on_duty: int        # punched in today, shift still active

    # ── Trip lifecycle ─────────────────────────────────────────────────────────
    trips_total: int
    trips_created: int          # waiting to start
    trips_active: int           # STARTED
    trips_completed: int
    trips_cancelled: int

    # ── Financial analytics (completed trips, all-time) ────────────────────────
    total_revenue: float
    total_diesel_used: float
    total_trip_expenses: float

    # ── Vehicle utilisation % ─────────────────────────────────────────────────
    # (vehicles_on_trip / total_active_vehicles) * 100
    utilisation_pct: float

    # ── Phase 5: Today-scoped KPIs (Optional — defaults to 0 for backward compat)
    trips_today: Optional[int]              = 0   # total trips created/active today
    trips_completed_today: Optional[int]    = 0   # trips completed today
    revenue_today: Optional[float]          = 0.0 # revenue from completed trips today
    revenue_this_month: Optional[float]     = 0.0 # revenue from completed trips this month

    # ── Phase 5: Rate + average KPIs ──────────────────────────────────────────
    trip_completion_rate: Optional[float]   = 0.0 # completed / total (non-cancelled) * 100
    avg_revenue_per_trip: Optional[float]   = 0.0 # avg revenue across all completed trips
    avg_diesel_per_trip: Optional[float]    = 0.0 # avg diesel (litres) per completed trip

    class Config:
        from_attributes = True
