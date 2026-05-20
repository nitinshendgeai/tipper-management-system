"""
Pydantic schemas for Vehicle Maintenance Management — Phase 9.
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import date, datetime


class MaintenanceCreate(BaseModel):
    vehicle_id: int
    maintenance_type: str = Field(
        default="ROUTINE",
        description="ROUTINE | REPAIR | TYRE | INSPECTION | OTHER",
    )
    description: str = Field(..., min_length=3, max_length=500)
    scheduled_date: Optional[date] = None
    cost: Optional[float] = Field(default=None, ge=0)
    odometer_km: Optional[float] = Field(default=None, ge=0)
    vendor_name: Optional[str] = Field(default=None, max_length=200)
    notes: Optional[str] = Field(default=None, max_length=500)


class MaintenanceUpdate(BaseModel):
    maintenance_type: Optional[str] = None
    description: Optional[str] = Field(default=None, min_length=3, max_length=500)
    status: Optional[str] = Field(
        default=None,
        description="SCHEDULED | IN_PROGRESS | COMPLETED | CANCELLED",
    )
    scheduled_date: Optional[date] = None
    completed_date: Optional[date] = None
    cost: Optional[float] = Field(default=None, ge=0)
    odometer_km: Optional[float] = Field(default=None, ge=0)
    vendor_name: Optional[str] = Field(default=None, max_length=200)
    notes: Optional[str] = Field(default=None, max_length=500)


class MaintenanceResponse(BaseModel):
    id: int
    company_id: Optional[str] = None
    vehicle_id: int
    vehicle_number: Optional[str] = None  # enriched
    maintenance_type: str
    status: str
    description: str
    scheduled_date: Optional[date] = None
    completed_date: Optional[date] = None
    cost: Optional[float] = None
    odometer_km: Optional[float] = None
    vendor_name: Optional[str] = None
    notes: Optional[str] = None
    created_by_user_id: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class MaintenanceSummary(BaseModel):
    """Lightweight list item — no enrichment overhead."""
    id: int
    vehicle_id: int
    vehicle_number: Optional[str] = None
    maintenance_type: str
    status: str
    description: str
    scheduled_date: Optional[date] = None
    completed_date: Optional[date] = None
    cost: Optional[float] = None
    vendor_name: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
