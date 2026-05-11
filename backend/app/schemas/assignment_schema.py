from pydantic import BaseModel
from typing import Optional
from datetime import datetime, date


# ─── CREATE ───────────────────────────────────────────────────────────────────

class AssignmentCreate(BaseModel):

    vehicle_id: int
    driver_id: int
    shift_date: Optional[date] = None
    remarks: Optional[str] = None


# ─── RELEASE ──────────────────────────────────────────────────────────────────

class AssignmentRelease(BaseModel):

    remarks: Optional[str] = None


# ─── RESPONSE ─────────────────────────────────────────────────────────────────

class AssignmentResponse(BaseModel):

    id: int
    vehicle_id: int
    driver_id: int
    assigned_by: Optional[int] = None
    assigned_at: Optional[datetime] = None
    shift_date: Optional[date] = None
    released_at: Optional[datetime] = None
    remarks: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ─── ENRICHED RESPONSE ────────────────────────────────────────────────────────

class AssignmentDetail(BaseModel):
    """Enriched assignment including vehicle number, driver name."""

    id: int
    vehicle_id: int
    vehicle_number: str
    vehicle_type: Optional[str] = None
    vehicle_status: str

    driver_id: int
    driver_name: str
    driver_mobile: str
    driver_status: str

    assigned_by: Optional[int] = None
    assigned_by_name: Optional[str] = None
    assigned_at: Optional[datetime] = None
    shift_date: Optional[date] = None
    released_at: Optional[datetime] = None
    remarks: Optional[str] = None
    is_active: bool


# ─── VEHICLE ASSIGNMENT STATUS ────────────────────────────────────────────────

class VehicleAssignmentStatus(BaseModel):
    """Quick lookup: is a vehicle assigned, and to whom?"""

    vehicle_id: int
    vehicle_number: str
    vehicle_status: str
    is_assigned: bool
    assignment_id: Optional[int] = None
    driver_id: Optional[int] = None
    driver_name: Optional[str] = None
    driver_mobile: Optional[str] = None
    driver_status: Optional[str] = None
    shift_date: Optional[date] = None
