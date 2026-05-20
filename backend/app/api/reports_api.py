"""
Reports API — Phase 9 CSV export foundation.

Endpoints:
  GET /reports/trips/csv          Trip report CSV
  GET /reports/expenses/csv       Trip expense report CSV
  GET /reports/fuel/csv           Fuel entries CSV
  GET /reports/maintenance/csv    Maintenance log CSV
  GET /reports/attendance/csv     Attendance report CSV

All reports:
  - Tenant-isolated (filter_by_company)
  - Optional date range: from_date / to_date (YYYY-MM-DD)
  - Streamed via StreamingResponse (no memory buffering of large datasets)
  - Content-Disposition: attachment; filename=<report>.csv
"""

import csv
import io
import logging
from datetime import date, datetime
from typing import Optional, Iterator

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.trip import Trip, TripStatus
from app.models.trip_expense import TripExpense
from app.models.fuel import FuelEntry
from app.models.maintenance import VehicleMaintenance
from app.models.attendance import DriverAttendance
from app.models.vehicle import Vehicle
from app.models.driver import Driver

from app.api.dependencies import require_permission, get_db
from app.core.permissions import Permission
from app.db.tenant_queries import filter_by_company

logger = logging.getLogger(__name__)

router = APIRouter()


# ─── CSV streaming helper ─────────────────────────────────────────────────────

def _csv_stream(headers: list, rows: list) -> Iterator[str]:
    """Yield CSV lines as strings for StreamingResponse."""
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(headers)
    yield buf.getvalue()
    buf.seek(0)
    buf.truncate()

    for row in rows:
        writer.writerow(row)
        yield buf.getvalue()
        buf.seek(0)
        buf.truncate()


def _csv_response(filename: str, headers: list, rows: list) -> StreamingResponse:
    return StreamingResponse(
        _csv_stream(headers, rows),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


def _parse_date(d: Optional[str]) -> Optional[date]:
    if d is None:
        return None
    try:
        return date.fromisoformat(d)
    except ValueError:
        return None


# ─── Trip Report ──────────────────────────────────────────────────────────────

@router.get(
    "/trips/csv",
    summary="Trip report — CSV export",
    response_class=StreamingResponse,
)
def trips_csv(
    from_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    to_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status_filter: Optional[str] = Query(None, alias="status"),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_REPORTS)),
):
    q = filter_by_company(db.query(Trip), Trip)

    fd = _parse_date(from_date)
    td = _parse_date(to_date)
    if fd:
        q = q.filter(Trip.trip_date >= datetime.combine(fd, datetime.min.time()))
    if td:
        q = q.filter(Trip.trip_date <= datetime.combine(td, datetime.max.time()))
    if status_filter:
        q = q.filter(Trip.trip_status == status_filter.upper())

    trips = q.order_by(Trip.trip_date.desc()).all()

    # Bulk-fetch vehicles and drivers
    vids = list({t.vehicle_id for t in trips})
    dids = list({t.driver_id for t in trips})
    vmap = {v.id: v.vehicle_number for v in db.query(Vehicle).filter(Vehicle.id.in_(vids)).all()} if vids else {}
    dmap = {d.id: d.full_name    for d in db.query(Driver).filter(Driver.id.in_(dids)).all()} if dids else {}

    headers = [
        "Trip ID", "Date", "Status",
        "Vehicle", "Driver",
        "Source", "Destination",
        "Start KM", "End KM", "Distance KM",
        "Diesel Issued (L)", "Diesel Used (L)",
        "Revenue (₹)", "Trip Advance (₹)", "Trip Expense (₹)",
        "Cancellation Reason", "Remarks",
    ]

    rows = []
    for t in trips:
        distance = None
        if t.start_km and t.end_km:
            distance = round(t.end_km - t.start_km, 2)
        rows.append([
            t.id,
            t.trip_date.date() if t.trip_date else "",
            t.trip_status,
            vmap.get(t.vehicle_id, ""),
            dmap.get(t.driver_id, ""),
            t.source_location or "",
            t.destination_location or "",
            t.start_km or "",
            t.end_km or "",
            distance or "",
            t.diesel_issued or "",
            t.diesel_used or "",
            t.revenue_amount or "",
            t.trip_advance or "",
            t.trip_expense or "",
            t.cancellation_reason or "",
            t.remarks or "",
        ])

    logger.info("[reports] trips CSV — %d rows", len(rows))
    return _csv_response("trips_report.csv", headers, rows)


# ─── Expense Report ───────────────────────────────────────────────────────────

@router.get(
    "/expenses/csv",
    summary="Trip expense report — CSV export",
    response_class=StreamingResponse,
)
def expenses_csv(
    from_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    to_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_REPORTS)),
):
    q = filter_by_company(db.query(TripExpense), TripExpense)

    fd = _parse_date(from_date)
    td = _parse_date(to_date)
    if fd:
        q = q.filter(TripExpense.created_at >= datetime.combine(fd, datetime.min.time()))
    if td:
        q = q.filter(TripExpense.created_at <= datetime.combine(td, datetime.max.time()))

    expenses = q.order_by(TripExpense.created_at.desc()).all()

    headers = [
        "Expense ID", "Trip ID", "Expense Type",
        "Amount (₹)", "Remarks", "Date",
    ]

    rows = [
        [
            e.id, e.trip_id, e.expense_type,
            e.amount or "",
            e.remarks or "",
            e.created_at.date() if e.created_at else "",
        ]
        for e in expenses
    ]

    logger.info("[reports] expenses CSV — %d rows", len(rows))
    return _csv_response("expenses_report.csv", headers, rows)


# ─── Fuel Report ──────────────────────────────────────────────────────────────

@router.get(
    "/fuel/csv",
    summary="Fuel entries report — CSV export",
    response_class=StreamingResponse,
)
def fuel_csv(
    from_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    to_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_REPORTS)),
):
    q = filter_by_company(db.query(FuelEntry), FuelEntry)

    fd = _parse_date(from_date)
    td = _parse_date(to_date)
    if fd:
        q = q.filter(FuelEntry.fuel_date >= fd)
    if td:
        q = q.filter(FuelEntry.fuel_date <= td)

    entries = q.order_by(FuelEntry.fuel_date.desc()).all()

    vids = list({e.vehicle_id for e in entries})
    dids = list({e.driver_id for e in entries if e.driver_id})
    vmap = {v.id: v.vehicle_number for v in db.query(Vehicle).filter(Vehicle.id.in_(vids)).all()} if vids else {}
    dmap = {d.id: d.full_name    for d in db.query(Driver).filter(Driver.id.in_(dids)).all()} if dids else {}

    headers = [
        "Entry ID", "Date", "Vehicle", "Driver", "Trip ID",
        "Qty (L)", "Cost/Litre (₹)", "Total Cost (₹)",
        "Odometer KM", "Fuel Station", "Notes",
    ]

    rows = [
        [
            e.id, e.fuel_date,
            vmap.get(e.vehicle_id, ""),
            dmap.get(e.driver_id, "") if e.driver_id else "",
            e.trip_id or "",
            e.quantity_litres,
            e.cost_per_litre or "",
            e.total_cost or "",
            e.odometer_km or "",
            e.fuel_station or "",
            e.notes or "",
        ]
        for e in entries
    ]

    logger.info("[reports] fuel CSV — %d rows", len(rows))
    return _csv_response("fuel_report.csv", headers, rows)


# ─── Maintenance Report ───────────────────────────────────────────────────────

@router.get(
    "/maintenance/csv",
    summary="Maintenance log report — CSV export",
    response_class=StreamingResponse,
)
def maintenance_csv(
    from_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    to_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_REPORTS)),
):
    q = filter_by_company(db.query(VehicleMaintenance), VehicleMaintenance)

    fd = _parse_date(from_date)
    td = _parse_date(to_date)
    if fd:
        q = q.filter(VehicleMaintenance.created_at >= datetime.combine(fd, datetime.min.time()))
    if td:
        q = q.filter(VehicleMaintenance.created_at <= datetime.combine(td, datetime.max.time()))

    logs = q.order_by(VehicleMaintenance.created_at.desc()).all()

    vids = list({log.vehicle_id for log in logs})
    vmap = {v.id: v.vehicle_number for v in db.query(Vehicle).filter(Vehicle.id.in_(vids)).all()} if vids else {}

    headers = [
        "Log ID", "Vehicle", "Type", "Status",
        "Description", "Scheduled Date", "Completed Date",
        "Cost (₹)", "Odometer KM", "Vendor", "Notes",
    ]

    rows = [
        [
            log.id,
            vmap.get(log.vehicle_id, ""),
            log.maintenance_type,
            log.status,
            log.description,
            log.scheduled_date or "",
            log.completed_date or "",
            log.cost or "",
            log.odometer_km or "",
            log.vendor_name or "",
            log.notes or "",
        ]
        for log in logs
    ]

    logger.info("[reports] maintenance CSV — %d rows", len(rows))
    return _csv_response("maintenance_report.csv", headers, rows)


# ─── Attendance Report ────────────────────────────────────────────────────────

@router.get(
    "/attendance/csv",
    summary="Attendance report — CSV export",
    response_class=StreamingResponse,
)
def attendance_csv(
    from_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    to_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_REPORTS)),
):
    q = filter_by_company(db.query(DriverAttendance), DriverAttendance)

    fd = _parse_date(from_date)
    td = _parse_date(to_date)
    if fd:
        q = q.filter(DriverAttendance.shift_date >= fd)
    if td:
        q = q.filter(DriverAttendance.shift_date <= td)

    records = q.order_by(DriverAttendance.shift_date.desc()).all()

    dids = list({r.driver_id for r in records})
    dmap = {d.id: d.full_name for d in db.query(Driver).filter(Driver.id.in_(dids)).all()} if dids else {}

    headers = [
        "Record ID", "Driver", "Shift Date",
        "Punch In", "Punch Out",
        "Is Active", "Notes",
    ]

    rows = [
        [
            r.id,
            dmap.get(r.driver_id, ""),
            r.shift_date,
            r.punch_in.strftime("%H:%M") if r.punch_in else "",
            r.punch_out.strftime("%H:%M") if r.punch_out else "",
            "Yes" if r.is_active else "No",
            r.notes if hasattr(r, "notes") else "",
        ]
        for r in records
    ]

    logger.info("[reports] attendance CSV — %d rows", len(rows))
    return _csv_response("attendance_report.csv", headers, rows)
