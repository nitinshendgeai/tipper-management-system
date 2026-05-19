"""
Analytics Service Layer — Phase 5: AI-Ready Data Foundation.

This service encapsulates all analytics query logic into reusable,
composable functions. It serves:
  1. The analytics API endpoints (current use)
  2. Future AI/ML services (structured output, no side effects)
  3. Dashboard aggregations (replaces ad-hoc queries in dashboard_api.py)

Design principles:
  - Pure functions — take db + company_id, return structured data
  - All queries scoped via filter_by_company()
  - No HTTP concerns — just DB logic
  - Returns typed dicts / Pydantic models directly
  - Composable — endpoints can call multiple functions
"""

from datetime import date, datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.trip import Trip, TripStatus
from app.models.trip_expense import TripExpense
from app.models.vehicle import Vehicle, VehicleStatus
from app.models.driver import Driver, DriverStatus
from app.models.assignment import DriverVehicleAssignment
from app.models.attendance import DriverAttendance, AttendanceStatus
from app.db.tenant_queries import filter_by_company


# ─── Time window helpers ──────────────────────────────────────────────────────

def today_window() -> tuple[date, date]:
    t = date.today()
    return t, t


def week_window() -> tuple[date, date]:
    """Monday → today."""
    today = date.today()
    monday = today - timedelta(days=today.weekday())
    return monday, today


def month_window() -> tuple[date, date]:
    """1st of current month → today."""
    today = date.today()
    first = today.replace(day=1)
    return first, today


def last_n_days_window(n: int = 30) -> tuple[date, date]:
    today = date.today()
    return today - timedelta(days=n - 1), today


def window_for_period(period: str) -> tuple[date, date]:
    """Resolve period string to (from_date, to_date)."""
    if period == "today":
        return today_window()
    elif period == "week":
        return week_window()
    elif period == "month":
        return month_window()
    else:  # "last_30_days" or default
        return last_n_days_window(30)


# ─── Trip analytics ───────────────────────────────────────────────────────────

def get_trip_counts_in_window(
    company_id,
    db: Session,
    from_date: date,
    to_date: date,
) -> dict:
    """
    Return trip counts by status for the given date window.
    Filters on trip_date (date the trip was created).
    AI use: volume forecasting input.
    """
    base = (
        filter_by_company(db.query(Trip), Trip)
        .filter(Trip.trip_date >= from_date, Trip.trip_date <= to_date)
    )

    created   = base.filter(Trip.trip_status == TripStatus.CREATED).count()
    started   = base.filter(Trip.trip_status == TripStatus.STARTED).count()
    completed = base.filter(Trip.trip_status == TripStatus.COMPLETED).count()
    cancelled = base.filter(Trip.trip_status == TripStatus.CANCELLED).count()
    total = created + started + completed + cancelled

    completion_rate = round((completed / total * 100), 1) if total > 0 else 0.0

    return {
        "created": created,
        "started": started,
        "completed": completed,
        "cancelled": cancelled,
        "total": total,
        "completion_rate": completion_rate,
    }


def get_trip_financials_in_window(
    company_id,
    db: Session,
    from_date: date,
    to_date: date,
) -> dict:
    """
    Revenue, diesel, expenses for completed trips in window.
    AI use: revenue forecasting, expense anomaly detection.
    """
    completed_trips = (
        filter_by_company(db.query(Trip), Trip)
        .filter(
            Trip.trip_status == TripStatus.COMPLETED,
            Trip.trip_date >= from_date,
            Trip.trip_date <= to_date,
        )
    )

    total_revenue = float(
        completed_trips.with_entities(
            func.coalesce(func.sum(Trip.revenue_amount), 0.0)
        ).scalar() or 0.0
    )
    total_diesel = float(
        completed_trips.with_entities(
            func.coalesce(func.sum(Trip.diesel_used), 0.0)
        ).scalar() or 0.0
    )
    total_distance = float(
        completed_trips.with_entities(
            func.coalesce(func.sum(Trip.end_km - Trip.start_km), 0.0)
        ).scalar() or 0.0
    )

    count = completed_trips.count()

    # Trip expenses from trip_expense table in window
    total_logged_expenses = float(
        filter_by_company(db.query(func.coalesce(func.sum(TripExpense.amount), 0.0)), TripExpense)
        .join(Trip, TripExpense.trip_id == Trip.id)
        .filter(Trip.trip_date >= from_date, Trip.trip_date <= to_date)
        .scalar() or 0.0
    )

    avg_revenue = round(total_revenue / count, 2) if count > 0 else 0.0
    avg_expense = round(total_logged_expenses / count, 2) if count > 0 else 0.0
    avg_distance = round(total_distance / count, 2) if count > 0 else 0.0
    fuel_efficiency = round(total_distance / total_diesel, 2) if total_diesel > 0 else 0.0

    return {
        "total_revenue": total_revenue,
        "total_diesel_expense": total_diesel,
        "total_trip_expenses": total_logged_expenses,
        "net_revenue": round(total_revenue - total_diesel - total_logged_expenses, 2),
        "avg_revenue_per_trip": avg_revenue,
        "avg_expense_per_trip": avg_expense,
        "total_distance_km": round(total_distance, 2),
        "total_diesel_litres": round(total_diesel, 2),
        "avg_fuel_efficiency_km_per_litre": fuel_efficiency,
        "avg_trip_distance_km": avg_distance,
        "completed_trip_count": count,
    }


# ─── Fleet analytics ──────────────────────────────────────────────────────────

def get_fleet_utilization(company_id, db: Session) -> dict:
    """
    Current fleet snapshot — statuses and utilization %.
    AI use: idle vehicle detection, capacity planning.
    """
    vehicles = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.is_active == True)
        .all()
    )
    total = len(vehicles)
    available   = sum(1 for v in vehicles if v.status == VehicleStatus.AVAILABLE)
    assigned    = sum(1 for v in vehicles if v.status == VehicleStatus.ASSIGNED)
    on_trip     = sum(1 for v in vehicles if v.status == VehicleStatus.ON_TRIP)
    maintenance = sum(1 for v in vehicles if v.status == VehicleStatus.MAINTENANCE)

    active = available + assigned + on_trip
    utilisation_pct = round((on_trip / active * 100), 1) if active > 0 else 0.0

    return {
        "total_vehicles": total,
        "available": available,
        "assigned": assigned,
        "on_trip": on_trip,
        "maintenance": maintenance,
        "active_fleet": active,
        "utilisation_pct": utilisation_pct,
    }


def get_vehicle_trip_stats(
    company_id,
    db: Session,
    from_date: date,
    to_date: date,
) -> list[dict]:
    """
    Per-vehicle trip summary in the given window.
    AI use: vehicle scoring, maintenance prediction.
    """
    vehicles = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.is_active == True)
        .all()
    )

    results = []
    for v in vehicles:
        trips = (
            filter_by_company(db.query(Trip), Trip)
            .filter(
                Trip.vehicle_id == v.id,
                Trip.trip_date >= from_date,
                Trip.trip_date <= to_date,
                Trip.trip_status == TripStatus.COMPLETED,
            )
        )
        count = trips.count()
        revenue = float(trips.with_entities(func.coalesce(func.sum(Trip.revenue_amount), 0.0)).scalar() or 0.0)
        diesel  = float(trips.with_entities(func.coalesce(func.sum(Trip.diesel_used), 0.0)).scalar() or 0.0)
        dist    = float(trips.with_entities(func.coalesce(func.sum(Trip.end_km - Trip.start_km), 0.0)).scalar() or 0.0)

        results.append({
            "vehicle_id": v.id,
            "vehicle_number": v.vehicle_number,
            "vehicle_type": getattr(v, "vehicle_type", "Tipper"),
            "total_trips": count,
            "total_distance_km": round(dist, 2),
            "total_revenue": round(revenue, 2),
            "total_diesel_used": round(diesel, 2),
            "avg_trip_distance_km": round(dist / count, 2) if count > 0 else 0.0,
            "current_status": v.status,
        })

    results.sort(key=lambda x: x["total_trips"], reverse=True)
    return results


# ─── Driver analytics ─────────────────────────────────────────────────────────

def get_driver_performance(
    driver_id: int,
    company_id,
    db: Session,
    from_date: date,
    to_date: date,
) -> Optional[dict]:
    """
    Individual driver performance in window.
    AI use: driver scoring, fatigue indicators, incentive calculation.
    """
    driver = (
        filter_by_company(db.query(Driver), Driver)
        .filter(Driver.id == driver_id, Driver.is_active == True)
        .first()
    )
    if not driver:
        return None

    trips = (
        filter_by_company(db.query(Trip), Trip)
        .filter(
            Trip.driver_id == driver_id,
            Trip.trip_date >= from_date,
            Trip.trip_date <= to_date,
        )
    )
    total     = trips.count()
    completed = trips.filter(Trip.trip_status == TripStatus.COMPLETED).count()
    cancelled = trips.filter(Trip.trip_status == TripStatus.CANCELLED).count()

    revenue = float(
        filter_by_company(db.query(func.coalesce(func.sum(Trip.revenue_amount), 0.0)), Trip)
        .filter(
            Trip.driver_id == driver_id,
            Trip.trip_status == TripStatus.COMPLETED,
            Trip.trip_date >= from_date,
            Trip.trip_date <= to_date,
        )
        .scalar() or 0.0
    )
    dist = float(
        filter_by_company(db.query(func.coalesce(func.sum(Trip.end_km - Trip.start_km), 0.0)), Trip)
        .filter(
            Trip.driver_id == driver_id,
            Trip.trip_status == TripStatus.COMPLETED,
            Trip.trip_date >= from_date,
            Trip.trip_date <= to_date,
        )
        .scalar() or 0.0
    )
    expenses = float(
        filter_by_company(db.query(func.coalesce(func.sum(TripExpense.amount), 0.0)), TripExpense)
        .join(Trip, TripExpense.trip_id == Trip.id)
        .filter(
            Trip.driver_id == driver_id,
            Trip.trip_date >= from_date,
            Trip.trip_date <= to_date,
        )
        .scalar() or 0.0
    )

    shifts = (
        filter_by_company(db.query(func.count(DriverAttendance.id)), DriverAttendance)
        .filter(
            DriverAttendance.driver_id == driver_id,
            DriverAttendance.shift_date >= from_date,
            DriverAttendance.shift_date <= to_date,
            DriverAttendance.status == AttendanceStatus.PRESENT,
        )
        .scalar() or 0
    )

    return {
        "driver_id": driver_id,
        "driver_name": driver.full_name,
        "total_trips": total,
        "trips_completed": completed,
        "trips_cancelled": cancelled,
        "completion_rate": round(completed / total * 100, 1) if total > 0 else 0.0,
        "total_distance_km": round(dist, 2),
        "total_revenue_generated": round(revenue, 2),
        "total_expenses_logged": round(expenses, 2),
        "avg_revenue_per_trip": round(revenue / completed, 2) if completed > 0 else 0.0,
        "total_shifts": shifts,
        "current_status": driver.status,
    }


def get_all_drivers_performance(
    company_id,
    db: Session,
    from_date: date,
    to_date: date,
) -> list[dict]:
    """
    All drivers' performance summary in window.
    AI use: fleet driver ranking, incentive tier assignment.
    """
    drivers = (
        filter_by_company(db.query(Driver), Driver)
        .filter(Driver.is_active == True)
        .all()
    )
    results = []
    for d in drivers:
        perf = get_driver_performance(d.id, company_id, db, from_date, to_date)
        if perf:
            results.append(perf)
    results.sort(key=lambda x: x["total_trips"], reverse=True)
    return results


# ─── Attendance analytics ─────────────────────────────────────────────────────

def get_attendance_summary_today(company_id, db: Session) -> dict:
    """
    Today's attendance summary — for dashboard and supervisor view.
    """
    today = date.today()
    records = (
        filter_by_company(db.query(DriverAttendance), DriverAttendance)
        .filter(
            DriverAttendance.shift_date == today,
            DriverAttendance.status == AttendanceStatus.PRESENT,
        )
        .all()
    )
    on_duty  = sum(1 for r in records if r.is_active)
    done     = sum(1 for r in records if not r.is_active)
    total    = len(records)

    return {
        "total_present": total,
        "currently_on_duty": on_duty,
        "total_punched_out": done,
    }


def get_attendance_in_window(
    company_id,
    db: Session,
    from_date: date,
    to_date: date,
) -> dict:
    """
    Attendance stats for a period — for KPI reporting.
    """
    total_shifts = (
        filter_by_company(db.query(func.count(DriverAttendance.id)), DriverAttendance)
        .filter(
            DriverAttendance.shift_date >= from_date,
            DriverAttendance.shift_date <= to_date,
            DriverAttendance.status == AttendanceStatus.PRESENT,
        )
        .scalar() or 0
    )
    return {"total_driver_shifts": total_shifts}


# ─── Supervisor snapshot ──────────────────────────────────────────────────────

def get_supervisor_snapshot(company_id, db: Session) -> dict:
    """
    Quick operational snapshot for SUPERVISOR role.
    All data is from today — fast, purpose-built.
    """
    today = date.today()

    trips_today = (
        filter_by_company(db.query(Trip), Trip)
        .filter(Trip.trip_date == today)
    )
    created   = trips_today.filter(Trip.trip_status == TripStatus.CREATED).count()
    started   = trips_today.filter(Trip.trip_status == TripStatus.STARTED).count()
    completed = trips_today.filter(Trip.trip_status == TripStatus.COMPLETED).count()

    active_assignments = (
        filter_by_company(db.query(func.count(DriverVehicleAssignment.id)), DriverVehicleAssignment)
        .filter(DriverVehicleAssignment.is_active == True)
        .scalar() or 0
    )

    attendance = get_attendance_summary_today(company_id, db)

    total_drivers = (
        filter_by_company(db.query(func.count(Driver.id)), Driver)
        .filter(Driver.is_active == True)
        .scalar() or 0
    )

    return {
        "today": today,
        "drivers_on_duty": attendance["currently_on_duty"],
        "drivers_off_duty": total_drivers - attendance["total_present"],
        "drivers_on_trip": (
            filter_by_company(db.query(func.count(Driver.id)), Driver)
            .filter(Driver.is_active == True, Driver.status == DriverStatus.ON_TRIP)
            .scalar() or 0
        ),
        "active_assignments": active_assignments,
        "trips_created_today": created,
        "trips_started_today": started,
        "trips_completed_today": completed,
        "pending_trips": created,
    }
