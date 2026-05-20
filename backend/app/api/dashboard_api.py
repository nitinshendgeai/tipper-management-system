"""
Dashboard Analytics API.

Phase 9 (DASH-001 fix): Consolidated from 21+ scalar queries to 7 GROUP BY
aggregation queries. Vehicle/driver/trip status counts now each use a single
GROUP BY query. Trip financials use a single conditional aggregation query.

Query budget:
  1. Vehicle status GROUP BY (all 5 vehicle status counts in one query)
  2. Driver status GROUP BY  (all 4 driver status counts in one query)
  3. Route count             (1 scalar)
  4. Attendance today        (1 scalar)
  5. Trip status + revenue + diesel GROUP BY (5 status counts + 2 sums in one)
  6. Total trip expenses     (1 scalar)
  7. Phase 5 time-windowed KPIs (3 analytics calls, each a single GROUP BY internally)

Total: ~7 DB round-trips (was ~21).
"""

import logging
from datetime import date as _date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, case

from app.models.vehicle import Vehicle, VehicleStatus
from app.models.driver import Driver, DriverStatus
from app.models.route import Route
from app.models.trip import Trip, TripStatus
from app.models.trip_expense import TripExpense
from app.models.attendance import DriverAttendance, AttendanceStatus

from app.schemas.dashboard_schema import DashboardStats
from app.api.dependencies import require_permission, get_db
from app.core.permissions import Permission
from app.db.tenant_queries import filter_by_company

# Phase 5 additions: time-windowed KPI helpers from analytics service
from app.services.analytics_service import (
    get_trip_counts_in_window,
    get_trip_financials_in_window,
    today_window,
    month_window,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get(
    "/stats",
    response_model=DashboardStats,
    summary="Operational fleet analytics dashboard",
)
def get_dashboard_stats(
    current_user=Depends(require_permission(Permission.VIEW_DASHBOARD)),
    db: Session = Depends(get_db),
):
    # ── Query 1: Vehicle status counts (one GROUP BY) ─────────────────────────
    # Replaces 5 separate scalar queries with a single aggregation.
    vehicle_status_rows = (
        filter_by_company(db.query(Vehicle.status, func.count(Vehicle.id)), Vehicle)
        .filter(Vehicle.is_active == True)
        .group_by(Vehicle.status)
        .all()
    )
    v_counts = {row.status: row[1] for row in vehicle_status_rows}
    total_vehicles        = sum(v_counts.values())
    vehicles_available    = v_counts.get(VehicleStatus.AVAILABLE, 0)
    vehicles_assigned     = v_counts.get(VehicleStatus.ASSIGNED, 0)
    vehicles_on_trip      = v_counts.get(VehicleStatus.ON_TRIP, 0)
    vehicles_maintenance  = v_counts.get(VehicleStatus.MAINTENANCE, 0)

    # ── Query 2: Driver status counts (one GROUP BY) ──────────────────────────
    driver_status_rows = (
        filter_by_company(db.query(Driver.status, func.count(Driver.id)), Driver)
        .filter(Driver.is_active == True)
        .group_by(Driver.status)
        .all()
    )
    d_counts        = {row.status: row[1] for row in driver_status_rows}
    total_drivers   = sum(d_counts.values())
    drivers_available = d_counts.get(DriverStatus.AVAILABLE, 0)
    drivers_on_trip   = d_counts.get(DriverStatus.ON_TRIP, 0)
    drivers_off_duty  = d_counts.get(DriverStatus.OFF_DUTY, 0)

    # ── Query 3: Route count ──────────────────────────────────────────────────
    total_routes = (
        filter_by_company(db.query(func.count(Route.id)), Route)
        .filter(Route.is_active == True)
        .scalar() or 0
    )

    # ── Query 4: Attendance today ─────────────────────────────────────────────
    drivers_on_duty = (
        filter_by_company(db.query(func.count(DriverAttendance.id)), DriverAttendance)
        .filter(
            DriverAttendance.shift_date == _date.today(),
            DriverAttendance.status == AttendanceStatus.PRESENT,
            DriverAttendance.is_active == True,
        )
        .scalar() or 0
    )

    # ── Query 5: Trip status counts + revenue + diesel (one GROUP BY) ─────────
    # Replaces 8 separate trip queries with one conditional aggregation.
    trip_agg_row = (
        filter_by_company(
            db.query(
                func.count(Trip.id).label("total"),
                func.sum(
                    case((Trip.trip_status == TripStatus.CREATED, 1), else_=0)
                ).label("created"),
                func.sum(
                    case((Trip.trip_status == TripStatus.STARTED, 1), else_=0)
                ).label("active"),
                func.sum(
                    case((Trip.trip_status == TripStatus.COMPLETED, 1), else_=0)
                ).label("completed"),
                func.sum(
                    case((Trip.trip_status == TripStatus.CANCELLED, 1), else_=0)
                ).label("cancelled"),
                func.coalesce(
                    func.sum(
                        case((Trip.trip_status == TripStatus.COMPLETED, Trip.revenue_amount), else_=0)
                    ), 0.0
                ).label("total_revenue"),
                func.coalesce(
                    func.sum(
                        case((Trip.trip_status == TripStatus.COMPLETED, Trip.diesel_used), else_=0)
                    ), 0.0
                ).label("total_diesel"),
            ),
            Trip,
        )
        .first()
    )

    trips_total     = int(trip_agg_row.total or 0)
    trips_created   = int(trip_agg_row.created or 0)
    trips_active    = int(trip_agg_row.active or 0)
    trips_completed = int(trip_agg_row.completed or 0)
    trips_cancelled = int(trip_agg_row.cancelled or 0)
    total_revenue   = float(trip_agg_row.total_revenue or 0.0)
    total_diesel_used = float(trip_agg_row.total_diesel or 0.0)

    # ── Query 6: Total trip expenses ──────────────────────────────────────────
    total_trip_expenses = float(
        filter_by_company(
            db.query(func.coalesce(func.sum(TripExpense.amount), 0.0)),
            TripExpense,
        ).scalar() or 0.0
    )

    # ── Fleet utilisation ──────────────────────────────────────────────────────
    active_fleet = vehicles_available + vehicles_assigned + vehicles_on_trip
    utilisation_pct = (
        round((vehicles_on_trip / active_fleet) * 100, 1)
        if active_fleet > 0 else 0.0
    )

    # ── Query 7 group: Phase 5 time-windowed KPIs ─────────────────────────────
    # Each of these calls a single GROUP BY internally in analytics_service.
    today_start, today_end = today_window()
    month_start, month_end = month_window()

    today_counts     = get_trip_counts_in_window(None, db, today_start, today_end)
    today_financials = get_trip_financials_in_window(None, db, today_start, today_end)
    month_financials = get_trip_financials_in_window(None, db, month_start, month_end)

    # All-time derived metrics
    settled = trips_completed + trips_cancelled
    trip_completion_rate = round(trips_completed / settled * 100, 1) if settled > 0 else 0.0
    avg_revenue_per_trip = round(total_revenue / trips_completed, 2) if trips_completed > 0 else 0.0
    avg_diesel_per_trip  = round(total_diesel_used / trips_completed, 2) if trips_completed > 0 else 0.0

    logger.debug("[dashboard] stats computed — vehicles=%d drivers=%d trips=%d", total_vehicles, total_drivers, trips_total)

    return DashboardStats(
        total_vehicles=total_vehicles,
        total_drivers=total_drivers,
        total_routes=total_routes,

        vehicles_available=vehicles_available,
        vehicles_assigned=vehicles_assigned,
        vehicles_on_trip=vehicles_on_trip,
        vehicles_maintenance=vehicles_maintenance,

        drivers_available=drivers_available,
        drivers_on_trip=drivers_on_trip,
        drivers_off_duty=drivers_off_duty,
        drivers_on_duty=drivers_on_duty,

        trips_total=trips_total,
        trips_created=trips_created,
        trips_active=trips_active,
        trips_completed=trips_completed,
        trips_cancelled=trips_cancelled,

        total_revenue=total_revenue,
        total_diesel_used=total_diesel_used,
        total_trip_expenses=total_trip_expenses,

        utilisation_pct=utilisation_pct,

        # Phase 5 time-windowed KPIs
        trips_today=today_counts["total"],
        trips_completed_today=today_counts["completed"],
        revenue_today=today_financials["total_revenue"],
        revenue_this_month=month_financials["total_revenue"],

        trip_completion_rate=trip_completion_rate,
        avg_revenue_per_trip=avg_revenue_per_trip,
        avg_diesel_per_trip=avg_diesel_per_trip,
    )
