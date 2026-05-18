"""
Driver Attendance API — Phase 4.

Workflow:
  DRIVER:     POST /attendance/punch-in  → marks self PRESENT (punch_in = now)
              POST /attendance/punch-out → ends own shift  (punch_out = now)
              GET  /attendance/me        → own attendance history

  SUPERVISOR: POST /attendance/punch-in  { driver_id }  → punch in any driver
              POST /attendance/punch-out { driver_id }  → punch out any driver
              GET  /attendance/today     → today's summary for whole company

  MANAGER / SUPER_ADMIN: all of the above + full history listing

Endpoints:
  POST /attendance/punch-in
  POST /attendance/punch-out
  GET  /attendance/me          (DRIVER own records)
  GET  /attendance/today       (SUPERVISOR+: today's company records)
  GET  /attendance/            (MANAGER+: full history, optional ?date=YYYY-MM-DD)
"""

from datetime import datetime, date as _date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.models.attendance import DriverAttendance, AttendanceStatus
from app.models.driver import Driver, DriverStatus

from app.schemas.attendance_schema import (
    AttendancePunchIn,
    AttendancePunchOut,
    AttendanceResponse,
    AttendanceTodaySummary,
)

from app.api.dependencies import require_permission, get_current_tenant_user, get_db
from app.core.permissions import Permission
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company

router = APIRouter()


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _enrich(record: DriverAttendance, db: Session) -> AttendanceResponse:
    """Attach driver_name to an attendance record."""
    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(Driver.id == record.driver_id).first()
    driver_name = driver.full_name if driver else "Unknown"

    return AttendanceResponse(
        id=record.id,
        driver_id=record.driver_id,
        driver_name=driver_name,
        shift_date=record.shift_date,
        punch_in=record.punch_in,
        punch_out=record.punch_out,
        status=record.status,
        is_active=record.is_active,
        created_at=record.created_at,
    )


def _resolve_driver(
    data_driver_id: Optional[int],
    current_user,
    db: Session,
    company_id,
) -> Driver:
    """
    Resolve which driver the action applies to.

    DRIVER role:
      - Attempts auto-resolution via Driver.user_id == current_user.id (Phase 4+).
      - Falls back to requiring explicit driver_id if no user_id link exists yet.
      - Validates driver belongs to the same company.

    SUPERVISOR / MANAGER / SUPER_ADMIN:
      - Must supply driver_id explicitly.
    """
    role_name = TenantContext.get_role_name()

    if role_name == "DRIVER":
        # Attempt auto-resolve via user_id link (set by MANAGER when creating driver account)
        driver = filter_by_company(
            db.query(Driver), Driver
        ).filter(
            Driver.user_id == current_user.id,
            Driver.is_active == True,
        ).first()

        if driver:
            return driver

        # Fallback: DRIVER provides their own driver_id (company-scoped, so safe)
        if not data_driver_id:
            raise HTTPException(
                status_code=422,
                detail=(
                    "Your account is not linked to a driver profile. "
                    "Please provide your driver_id, or ask your manager to link your account."
                ),
            )

        driver = filter_by_company(
            db.query(Driver), Driver
        ).filter(
            Driver.id == data_driver_id,
            Driver.is_active == True,
        ).first()
        if not driver:
            raise HTTPException(status_code=404, detail="Driver not found in your company")
        return driver

    # SUPERVISOR / MANAGER / SUPER_ADMIN must supply driver_id
    if not data_driver_id:
        raise HTTPException(
            status_code=422,
            detail="driver_id is required for this role",
        )

    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(
        Driver.id == data_driver_id,
        Driver.is_active == True,
    ).first()
    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")

    return driver


# ─── PUNCH IN ─────────────────────────────────────────────────────────────────

@router.post(
    "/punch-in",
    response_model=AttendanceResponse,
    summary="Mark driver as PRESENT — creates attendance record for today",
)
def punch_in(
    data: AttendancePunchIn = AttendancePunchIn(),
    current_user=Depends(require_permission(Permission.MANAGE_ATTENDANCE)),
    db: Session = Depends(get_db),
):
    company_id = TenantContext.get_company_id()
    today = _date.today()

    driver = _resolve_driver(data.driver_id, current_user, db, company_id)

    # Guard: already punched in today?
    existing = (
        filter_by_company(db.query(DriverAttendance), DriverAttendance)
        .filter(
            DriverAttendance.driver_id == driver.id,
            DriverAttendance.shift_date == today,
        )
        .first()
    )
    if existing:
        if existing.is_active:
            raise HTTPException(
                status_code=409,
                detail=f"Driver {driver.full_name} is already punched in today",
            )
        # Shift completed — cannot punch in again same day
        raise HTTPException(
            status_code=409,
            detail=f"Driver {driver.full_name} has already completed a shift today",
        )

    # Create attendance record
    record = DriverAttendance(
        company_id=company_id,
        driver_id=driver.id,
        shift_date=today,
        punch_in=datetime.utcnow(),
        status=AttendanceStatus.PRESENT,
        is_active=True,
    )
    db.add(record)

    # Set driver status to AVAILABLE so they can be assigned a trip
    driver.status = DriverStatus.AVAILABLE
    db.add(driver)

    db.commit()
    db.refresh(record)

    return _enrich(record, db)


# ─── PUNCH OUT ────────────────────────────────────────────────────────────────

@router.post(
    "/punch-out",
    response_model=AttendanceResponse,
    summary="End driver shift — sets punch_out timestamp",
)
def punch_out(
    data: AttendancePunchOut = AttendancePunchOut(),
    current_user=Depends(require_permission(Permission.MANAGE_ATTENDANCE)),
    db: Session = Depends(get_db),
):
    company_id = TenantContext.get_company_id()
    today = _date.today()

    driver = _resolve_driver(data.driver_id, current_user, db, company_id)

    # Guard: driver must be currently on an active shift
    record = (
        filter_by_company(db.query(DriverAttendance), DriverAttendance)
        .filter(
            DriverAttendance.driver_id == driver.id,
            DriverAttendance.shift_date == today,
            DriverAttendance.is_active == True,
        )
        .first()
    )
    if not record:
        raise HTTPException(
            status_code=404,
            detail=f"No active shift found for {driver.full_name} today — punch in first",
        )

    # Guard: driver cannot punch out while on a trip
    if driver.status == DriverStatus.ON_TRIP:
        raise HTTPException(
            status_code=409,
            detail=f"Driver {driver.full_name} is currently ON_TRIP — complete the trip first",
        )

    # Close the attendance record
    record.punch_out = datetime.utcnow()
    record.is_active = False
    db.add(record)

    # Set driver status back to OFF_DUTY
    driver.status = DriverStatus.OFF_DUTY
    db.add(driver)

    db.commit()
    db.refresh(record)

    return _enrich(record, db)


# ─── MY ATTENDANCE (DRIVER self-view) ────────────────────────────────────────

@router.get(
    "/me",
    response_model=list[AttendanceResponse],
    summary="Get own attendance history (DRIVER role)",
)
def my_attendance(
    current_user=Depends(require_permission(Permission.VIEW_ATTENDANCE)),
    db: Session = Depends(get_db),
):
    role_name = TenantContext.get_role_name()

    if role_name != "DRIVER":
        raise HTTPException(
            status_code=403,
            detail="Use GET /attendance/ for non-driver roles",
        )

    # Find this user's driver profile
    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(Driver.user_id == current_user.id).first()

    if not driver:
        raise HTTPException(
            status_code=404,
            detail="No driver profile found for your account",
        )

    records = (
        filter_by_company(db.query(DriverAttendance), DriverAttendance)
        .filter(DriverAttendance.driver_id == driver.id)
        .order_by(DriverAttendance.shift_date.desc())
        .limit(30)
        .all()
    )

    return [_enrich(r, db) for r in records]


# ─── TODAY'S SUMMARY ─────────────────────────────────────────────────────────

@router.get(
    "/today",
    response_model=list[AttendanceResponse],
    summary="Get today's attendance records for the company (SUPERVISOR+)",
)
def today_attendance(
    current_user=Depends(require_permission(Permission.VIEW_ATTENDANCE)),
    db: Session = Depends(get_db),
):
    today = _date.today()

    records = (
        filter_by_company(db.query(DriverAttendance), DriverAttendance)
        .filter(DriverAttendance.shift_date == today)
        .order_by(DriverAttendance.punch_in.desc())
        .all()
    )

    return [_enrich(r, db) for r in records]


# ─── FULL HISTORY ─────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=list[AttendanceResponse],
    summary="List attendance records — optionally filter by date or driver (MANAGER+)",
)
def list_attendance(
    shift_date: Optional[str] = Query(default=None, description="YYYY-MM-DD format"),
    driver_id: Optional[int] = Query(default=None),
    current_user=Depends(require_permission(Permission.VIEW_ATTENDANCE)),
    db: Session = Depends(get_db),
):
    role_name = TenantContext.get_role_name()

    # Restrict DRIVER and SUPERVISOR — they should use /me or /today
    if role_name == "DRIVER":
        raise HTTPException(
            status_code=403,
            detail="Use GET /attendance/me for your own attendance history",
        )

    query = filter_by_company(db.query(DriverAttendance), DriverAttendance)

    if shift_date:
        try:
            parsed_date = _date.fromisoformat(shift_date)
        except ValueError:
            raise HTTPException(status_code=422, detail="shift_date must be YYYY-MM-DD")
        query = query.filter(DriverAttendance.shift_date == parsed_date)

    if driver_id:
        query = query.filter(DriverAttendance.driver_id == driver_id)

    records = query.order_by(
        DriverAttendance.shift_date.desc(),
        DriverAttendance.punch_in.desc(),
    ).all()

    return [_enrich(r, db) for r in records]
