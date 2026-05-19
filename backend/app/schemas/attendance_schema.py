"""
Pydantic schemas for Driver Attendance API.
"""

from datetime import datetime, date
from typing import Optional

from pydantic import BaseModel


# ─── Request Schemas ──────────────────────────────────────────────────────────

class AttendancePunchIn(BaseModel):
    """
    Used by SUPERVISOR / MANAGER to punch in a specific driver.
    DRIVER role omits driver_id — the backend infers it from their JWT.
    """
    driver_id: Optional[int] = None


class AttendancePunchOut(BaseModel):
    """
    Used by SUPERVISOR / MANAGER to punch out a specific driver by attendance ID.
    DRIVER role punches out their own active record — no body needed.
    """
    driver_id: Optional[int] = None


# ─── Response Schemas ─────────────────────────────────────────────────────────

class AttendanceResponse(BaseModel):
    id: int
    driver_id: int
    driver_name: str
    shift_date: date
    punch_in: Optional[datetime] = None
    punch_out: Optional[datetime] = None
    status: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AttendanceTodaySummary(BaseModel):
    """Lightweight summary for dashboard stats."""
    total_present: int
    currently_on_duty: int   # punched in, not yet punched out
    total_punched_out: int   # completed shift today
