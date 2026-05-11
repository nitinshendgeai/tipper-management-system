from pydantic import BaseModel
from typing import Optional


class DashboardStats(BaseModel):
    """
    Operational fleet analytics for the ERP dashboard.
    AI-ready: all fields needed for anomaly detection, utilisation analysis.
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

    # ── Trip lifecycle ─────────────────────────────────────────────────────────
    trips_total: int
    trips_created: int          # waiting to start
    trips_active: int           # STARTED
    trips_completed: int
    trips_cancelled: int

    # ── Financial analytics (completed trips) ──────────────────────────────────
    total_revenue: float
    total_diesel_used: float
    total_trip_expenses: float

    # ── Vehicle utilisation % ─────────────────────────────────────────────────
    # (vehicles_on_trip / total_active_vehicles) * 100
    utilisation_pct: float

    class Config:
        from_attributes = True
