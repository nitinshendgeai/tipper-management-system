"""
Analytics API — Phase 5: Analytics + Dashboard Intelligence + AI Foundation.

Endpoints:
  GET /analytics/operational     — time-windowed KPIs for MANAGER / SUPER_ADMIN
  GET /analytics/driver/me       — DRIVER's own performance stats
  GET /analytics/fleet           — per-vehicle utilization for MANAGER / SUPER_ADMIN
  GET /analytics/alerts          — smart operational alerts for SUPERVISOR+

All responses are company-scoped (tenant-isolated) via TenantContext.
All analytics logic lives in services/analytics_service.py and services/alert_service.py.
"""

from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.dependencies import require_permission, get_db
from app.core.permissions import Permission
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company
from app.models.driver import Driver
from app.models.attendance import DriverAttendance, AttendanceStatus

from app.services.analytics_service import (
    window_for_period,
    get_trip_counts_in_window,
    get_trip_financials_in_window,
    get_fleet_utilization,
    get_vehicle_trip_stats,
    get_driver_performance,
    get_all_drivers_performance,
    get_attendance_summary_today,
    get_attendance_in_window,
    get_supervisor_snapshot,
)
from app.services.alert_service import get_operational_alerts

from app.schemas.analytics_schema import (
    TimeWindow,
    OperationalKPIs,
    FleetAnalytics,
    VehicleUtilization,
    DriverPerformance,
    DriverSelfStats,
    SupervisorSnapshot,
    AlertsResponse,
    AlertSeverity,
)

router = APIRouter()


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _build_time_window(period: str) -> TimeWindow:
    from_date, to_date = window_for_period(period)
    return TimeWindow(period=period, from_date=from_date, to_date=to_date)


def _resolve_driver_profile(current_user, db: Session) -> Driver:
    """
    Resolve the DRIVER's profile from their user_id link.
    Raises 404 if no driver profile is linked to this user account.
    """
    company_id = TenantContext.get_company_id()
    driver = (
        filter_by_company(db.query(Driver), Driver)
        .filter(
            Driver.user_id == current_user.id,
            Driver.is_active == True,
        )
        .first()
    )
    if not driver:
        raise HTTPException(
            status_code=404,
            detail=(
                "No driver profile linked to your account. "
                "Ask your manager to link your user account to a driver profile."
            ),
        )
    return driver


# ─── Operational KPIs (MANAGER / SUPER_ADMIN) ─────────────────────────────────

@router.get(
    "/operational",
    response_model=OperationalKPIs,
    summary="Time-windowed operational KPIs",
    description=(
        "Returns trip volumes, financial metrics, distance, fuel, and attendance "
        "for the selected period. Available to MANAGER and SUPER_ADMIN."
    ),
)
def get_operational_kpis(
    period: str = Query(
        default="today",
        description="Time window: today | week | month | last_30_days",
    ),
    current_user=Depends(require_permission(Permission.VIEW_ANALYTICS)),
    db: Session = Depends(get_db),
):
    company_id = TenantContext.get_company_id()
    from_date, to_date = window_for_period(period)
    window = TimeWindow(period=period, from_date=from_date, to_date=to_date)

    counts    = get_trip_counts_in_window(company_id, db, from_date, to_date)
    financials = get_trip_financials_in_window(company_id, db, from_date, to_date)
    attendance = get_attendance_in_window(company_id, db, from_date, to_date)

    return OperationalKPIs(
        window=window,

        # Trip volumes
        trips_created=counts["created"],
        trips_started=counts["started"],
        trips_completed=counts["completed"],
        trips_cancelled=counts["cancelled"],
        trip_completion_rate=counts["completion_rate"],

        # Financial
        total_revenue=financials["total_revenue"],
        total_diesel_expense=financials["total_diesel_expense"],
        total_trip_expenses=financials["total_trip_expenses"],
        net_revenue=financials["net_revenue"],
        avg_revenue_per_trip=financials["avg_revenue_per_trip"],
        avg_expense_per_trip=financials["avg_expense_per_trip"],

        # Distance / fuel
        total_distance_km=financials["total_distance_km"],
        total_diesel_litres=financials["total_diesel_litres"],
        avg_fuel_efficiency_km_per_litre=financials["avg_fuel_efficiency_km_per_litre"],

        # Attendance
        total_driver_shifts=attendance["total_driver_shifts"],
    )


# ─── Fleet Analytics (MANAGER / SUPER_ADMIN) ──────────────────────────────────

@router.get(
    "/fleet",
    response_model=FleetAnalytics,
    summary="Fleet utilization analytics",
    description=(
        "Returns per-vehicle trip counts, distances, revenue, and fuel for the "
        "selected period. Sorted by total trips descending."
    ),
)
def get_fleet_analytics(
    period: str = Query(
        default="month",
        description="Time window: today | week | month | last_30_days",
    ),
    current_user=Depends(require_permission(Permission.VIEW_ANALYTICS)),
    db: Session = Depends(get_db),
):
    company_id = TenantContext.get_company_id()
    from_date, to_date = window_for_period(period)
    window = TimeWindow(period=period, from_date=from_date, to_date=to_date)

    fleet_snapshot = get_fleet_utilization(company_id, db)
    vehicle_stats  = get_vehicle_trip_stats(company_id, db, from_date, to_date)

    total_trips_all = sum(v["total_trips"] for v in vehicle_stats)
    vehicle_count   = fleet_snapshot["total_vehicles"]
    avg_trips = round(total_trips_all / vehicle_count, 2) if vehicle_count > 0 else 0.0

    vehicles = [
        VehicleUtilization(
            vehicle_id=v["vehicle_id"],
            vehicle_number=v["vehicle_number"],
            vehicle_type=v["vehicle_type"],
            total_trips=v["total_trips"],
            total_distance_km=v["total_distance_km"],
            total_revenue=v["total_revenue"],
            total_diesel_used=v["total_diesel_used"],
            avg_trip_distance_km=v["avg_trip_distance_km"],
            current_status=v["current_status"],
        )
        for v in vehicle_stats
    ]

    return FleetAnalytics(
        window=window,
        total_vehicles=fleet_snapshot["total_vehicles"],
        active_vehicles=fleet_snapshot["active_fleet"],
        utilisation_pct=fleet_snapshot["utilisation_pct"],
        avg_trips_per_vehicle=avg_trips,
        top_vehicles=vehicles,
    )


# ─── Driver Self-Stats (DRIVER role) ──────────────────────────────────────────

@router.get(
    "/driver/me",
    response_model=DriverSelfStats,
    summary="Driver's own performance stats",
    description=(
        "Returns the authenticated DRIVER's trip stats, revenue, distances, "
        "attendance, and today's punch-in status for the selected period."
    ),
)
def get_my_driver_stats(
    period: str = Query(
        default="month",
        description="Time window: today | week | month | last_30_days",
    ),
    current_user=Depends(require_permission(Permission.VIEW_TRIPS)),
    db: Session = Depends(get_db),
):
    # Only DRIVER role should use this endpoint.
    # MANAGER/SUPERVISOR accessing their own stats should use /analytics/operational.
    company_id = TenantContext.get_company_id()
    role_name  = TenantContext.get_role_name()

    if role_name != "DRIVER":
        raise HTTPException(
            status_code=403,
            detail="This endpoint is only available to the DRIVER role.",
        )

    driver = _resolve_driver_profile(current_user, db)

    from_date, to_date = window_for_period(period)
    window = TimeWindow(period=period, from_date=from_date, to_date=to_date)

    perf = get_driver_performance(driver.id, company_id, db, from_date, to_date)
    if not perf:
        raise HTTPException(status_code=404, detail="Driver performance data not found.")

    # Today's attendance
    today_record = (
        filter_by_company(db.query(DriverAttendance), DriverAttendance)
        .filter(
            DriverAttendance.driver_id == driver.id,
            DriverAttendance.shift_date == date.today(),
            DriverAttendance.status == AttendanceStatus.PRESENT,
        )
        .first()
    )
    punched_in_today = today_record is not None
    punch_in_time    = today_record.punch_in if today_record else None

    return DriverSelfStats(
        window=window,
        driver_name=perf["driver_name"],
        total_trips=perf["total_trips"],
        trips_completed=perf["trips_completed"],
        trips_cancelled=perf["trips_cancelled"],
        total_distance_km=perf["total_distance_km"],
        total_revenue_generated=perf["total_revenue_generated"],
        total_expenses_logged=perf["total_expenses_logged"],
        total_shifts=perf["total_shifts"],
        current_status=str(perf["current_status"]),
        punched_in_today=punched_in_today,
        punch_in_time=punch_in_time,
    )


# ─── Smart Operational Alerts (SUPERVISOR / MANAGER / SUPER_ADMIN) ────────────

@router.get(
    "/alerts",
    response_model=AlertsResponse,
    summary="Smart operational alerts",
    description=(
        "Detects and returns operational anomalies: overdue trips, excessive expenses, "
        "low attendance, inactive vehicles/drivers, high cancellation rates. "
        "Sorted by severity (CRITICAL → HIGH → MEDIUM → LOW)."
    ),
)
def get_alerts(
    current_user=Depends(require_permission(Permission.VIEW_DASHBOARD)),
    db: Session = Depends(get_db),
):
    company_id = TenantContext.get_company_id()

    alerts = get_operational_alerts(company_id, db)

    critical_count = sum(1 for a in alerts if a.severity == AlertSeverity.CRITICAL)
    high_count     = sum(1 for a in alerts if a.severity == AlertSeverity.HIGH)

    return AlertsResponse(
        total_alerts=len(alerts),
        critical_count=critical_count,
        high_count=high_count,
        alerts=alerts,
    )


# ─── Supervisor Snapshot ──────────────────────────────────────────────────────

@router.get(
    "/supervisor/snapshot",
    response_model=SupervisorSnapshot,
    summary="Supervisor operational snapshot",
    description=(
        "Quick operational overview for SUPERVISOR role: drivers on/off duty, "
        "active assignments, today's trip counts. All data is from today."
    ),
)
def get_supervisor_snap(
    current_user=Depends(require_permission(Permission.VIEW_DASHBOARD)),
    db: Session = Depends(get_db),
):
    company_id = TenantContext.get_company_id()
    snap = get_supervisor_snapshot(company_id, db)

    return SupervisorSnapshot(
        today=snap["today"],
        drivers_on_duty=snap["drivers_on_duty"],
        drivers_off_duty=snap["drivers_off_duty"],
        drivers_on_trip=snap["drivers_on_trip"],
        active_assignments=snap["active_assignments"],
        trips_created_today=snap["trips_created_today"],
        trips_started_today=snap["trips_started_today"],
        trips_completed_today=snap["trips_completed_today"],
        pending_trips=snap["pending_trips"],
    )
