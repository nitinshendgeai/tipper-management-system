from fastapi import APIRouter, Depends

from sqlalchemy.orm import Session
from sqlalchemy import func

from datetime import date as _date

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

# Phase 2 fix (DB-001): get_db() removed from local definition — imported from dependencies

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
    # ── Vehicle counts (scoped to company) ────────────────────────────────────

    total_vehicles = filter_by_company(db.query(func.count(Vehicle.id)), Vehicle).filter(Vehicle.is_active == True).scalar() or 0

    vehicles_available   = filter_by_company(db.query(func.count(Vehicle.id)), Vehicle).filter(Vehicle.is_active == True, Vehicle.status == VehicleStatus.AVAILABLE).scalar() or 0
    vehicles_assigned    = filter_by_company(db.query(func.count(Vehicle.id)), Vehicle).filter(Vehicle.is_active == True, Vehicle.status == VehicleStatus.ASSIGNED).scalar() or 0
    vehicles_on_trip     = filter_by_company(db.query(func.count(Vehicle.id)), Vehicle).filter(Vehicle.is_active == True, Vehicle.status == VehicleStatus.ON_TRIP).scalar() or 0
    vehicles_maintenance = filter_by_company(db.query(func.count(Vehicle.id)), Vehicle).filter(Vehicle.is_active == True, Vehicle.status == VehicleStatus.MAINTENANCE).scalar() or 0

    # ── Driver counts (scoped to company) ─────────────────────────────────────

    total_drivers = filter_by_company(db.query(func.count(Driver.id)), Driver).filter(Driver.is_active == True).scalar() or 0

    drivers_available = filter_by_company(db.query(func.count(Driver.id)), Driver).filter(Driver.is_active == True, Driver.status == DriverStatus.AVAILABLE).scalar() or 0
    drivers_on_trip   = filter_by_company(db.query(func.count(Driver.id)), Driver).filter(Driver.is_active == True, Driver.status == DriverStatus.ON_TRIP).scalar() or 0
    drivers_off_duty  = filter_by_company(db.query(func.count(Driver.id)), Driver).filter(Driver.is_active == True, Driver.status == DriverStatus.OFF_DUTY).scalar() or 0

    # ── Route count (scoped to company) ───────────────────────────────────────

    total_routes = filter_by_company(db.query(func.count(Route.id)), Route).filter(Route.is_active == True).scalar() or 0

    # ── Attendance — drivers on duty today (scoped to company) ────────────────

    drivers_on_duty = (
        filter_by_company(db.query(func.count(DriverAttendance.id)), DriverAttendance)
        .filter(
            DriverAttendance.shift_date == _date.today(),
            DriverAttendance.status == AttendanceStatus.PRESENT,
            DriverAttendance.is_active == True,
        )
        .scalar() or 0
    )

    # ── Trip lifecycle counts (scoped to company) ──────────────────────────────

    trips_total     = filter_by_company(db.query(func.count(Trip.id)), Trip).scalar() or 0
    trips_created   = filter_by_company(db.query(func.count(Trip.id)), Trip).filter(Trip.trip_status == TripStatus.CREATED).scalar() or 0
    trips_active    = filter_by_company(db.query(func.count(Trip.id)), Trip).filter(Trip.trip_status == TripStatus.STARTED).scalar() or 0
    trips_completed = filter_by_company(db.query(func.count(Trip.id)), Trip).filter(Trip.trip_status == TripStatus.COMPLETED).scalar() or 0
    trips_cancelled = filter_by_company(db.query(func.count(Trip.id)), Trip).filter(Trip.trip_status == TripStatus.CANCELLED).scalar() or 0

    # ── Financial analytics (completed trips, scoped to company) ──────────────

    total_revenue = float(
        filter_by_company(db.query(func.coalesce(func.sum(Trip.revenue_amount), 0.0)), Trip)
        .filter(Trip.trip_status == TripStatus.COMPLETED)
        .scalar() or 0.0
    )

    total_diesel_used = float(
        filter_by_company(db.query(func.coalesce(func.sum(Trip.diesel_used), 0.0)), Trip)
        .filter(Trip.trip_status == TripStatus.COMPLETED)
        .scalar() or 0.0
    )

    # Sum from trip_expenses table (scoped to company)
    total_trip_expenses = float(
        filter_by_company(db.query(func.coalesce(func.sum(TripExpense.amount), 0.0)), TripExpense)
        .scalar() or 0.0
    )

    # ── Fleet utilisation ──────────────────────────────────────────────────────
    # (vehicles currently on trip / total active vehicles) * 100
    active_fleet = vehicles_available + vehicles_assigned + vehicles_on_trip
    utilisation_pct = (
        round((vehicles_on_trip / active_fleet) * 100, 1)
        if active_fleet > 0 else 0.0
    )

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
    )
