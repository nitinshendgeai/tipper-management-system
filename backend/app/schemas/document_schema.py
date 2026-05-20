"""
Pydantic schemas for Document Management — Phase 9.
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, datetime


class DocumentCreate(BaseModel):
    category: str = Field(
        ...,
        description="DRIVER | VEHICLE | INSURANCE | PERMIT | OTHER",
    )
    document_name: str = Field(..., min_length=2, max_length=200)
    document_number: Optional[str] = Field(default=None, max_length=100)
    vehicle_id: Optional[int] = None
    driver_id: Optional[int] = None
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    file_path: Optional[str] = Field(default=None, max_length=500)
    notes: Optional[str] = Field(default=None, max_length=500)


class DocumentUpdate(BaseModel):
    category: Optional[str] = None
    document_name: Optional[str] = Field(default=None, min_length=2, max_length=200)
    document_number: Optional[str] = Field(default=None, max_length=100)
    vehicle_id: Optional[int] = None
    driver_id: Optional[int] = None
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    file_path: Optional[str] = Field(default=None, max_length=500)
    notes: Optional[str] = Field(default=None, max_length=500)


class DocumentResponse(BaseModel):
    id: int
    company_id: Optional[str] = None
    category: str
    document_name: str
    document_number: Optional[str] = None
    vehicle_id: Optional[int] = None
    vehicle_number: Optional[str] = None   # enriched
    driver_id: Optional[int] = None
    driver_name: Optional[str] = None      # enriched
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    is_expired: Optional[bool] = None      # computed server-side
    days_to_expiry: Optional[int] = None   # computed server-side
    file_path: Optional[str] = None
    notes: Optional[str] = None
    created_by_user_id: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
