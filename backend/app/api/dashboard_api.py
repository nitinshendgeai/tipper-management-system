from fastapi import APIRouter, Depends

from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.session import SessionLocal

from app.models.vehicle import Vehicle, VehicleStatus
from app.models.driver import Driver, DriverStatus
from app.models.route import Route
from app.models.trip import Trip, TripStatus
from app.models.trip_expense import TripExpense

from app.schemas.dashboard_schema import DashboardStats


router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get(
    "/stats",
    response_model=DashboardStats,
    summary="Operational fleet analytics dashboard",
)
def get_dashboard_stats(
    db: Session = Depends(get_db),
):
    # ── Vehicle counts ─────────────────────────────────────────────────────────

    total_vehicles = db.query(func.count(Vehicle.id)).filter(Vehicle.is_active == True).scalar() or 0

    vehicles_available   = db.query(func.count(Vehicle.id)).filter(Vehicle.is_active == True, Vehicle.status == VehicleStatus.AVAILABLE).scalar() or 0
    vehicles_assigned    = db.query(func.count(Vehicle.id)).filter(Vehicle.is_active == True, Vehicle.status == VehicleStatus.ASSIGNED).scalar() or 0
    vehicles_on_trip     = db.query(func.count(Vehicle.id)).filter(Vehicle.is_active == True, Vehicle.status == VehicleStatus.ON_TRIP).scalar() or 0
    vehicles_maintenance = db.query(func.count(Vehicle.id)).filter(Vehicle.is_active == True, Vehicle.status == VehicleStatus.MAINTENANCE).scalar() or 0

    # ── Driver counts ──────────────────────────────────────────────────────────

    total_drivers = db.query(func.count(Driver.id)).filter(Driver.is_active == True).scalar() or 0

    drivers_available = db.query(func.count(Driver.id)).filter(Driver.is_active == True, Driver.status == DriverStatus.AVAILABLE).scalar() or 0
    drivers_on_trip   = db.query(func.count(Driver.id)).filter(Driver.is_active == True, Driver.status == DriverStatus.ON_TRIP).scalar() or 0
    drivers_off_duty  = db.query(func.count(Driver.id)).filter(Driver.is_active == True, Driver.status == DriverStatus.OFF_DUTY).scalar() or 0

    # ── Route count ────────────────────────────────────────────────────────────

    total_routes = db.query(func.count(Route.id)).filter(Route.is_active == True).scalar() or 0

    # ── Trip lifecycle counts ──────────────────────────────────────────────────

    trips_total     = db.query(func.count(Trip.id)).scalar() or 0
    trips_created   = db.query(func.count(Trip.id)).filter(Trip.trip_status == TripStatus.CREATED).scalar() or 0
    trips_active    = db.query(func.count(Trip.id)).filter(Trip.trip_status == TripStatus.STARTED).scalar() or 0
    trips_completed = db.query(func.count(Trip.id)).filter(Trip.trip_status == TripStatus.COMPLETED).scalar() or 0
    trips_cancelled = db.query(func.count(Trip.id)).filter(Trip.trip_status == TripStatus.CANCELLED).scalar() or 0

    # ── Financial analytics (completed trips) ──────────────────────────────────

    total_revenue = float(
        db.query(func.coalesce(func.sum(Trip.revenue_amount), 0.0))
        .filter(Trip.trip_status == TripStatus.COMPLETED)
        .scalar() or 0.0
    )

    total_diesel_used = float(
        db.query(func.coalesce(func.sum(Trip.diesel_used), 0.0))
        .filter(Trip.trip_status == TripStatus.COMPLETED)
        .scalar() or 0.0
    )

    # Sum from trip_expenses table (all logged individual expenses)
    total_trip_expenses = float(
        db.query(func.coalesce(func.sum(TripExpense.amount), 0.0))
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
