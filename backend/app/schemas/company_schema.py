"""
Pydantic schemas for Company registration and responses.
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
import uuid


class CompanyRegisterRequest(BaseModel):
    company_name: str = Field(..., min_length=3, max_length=255)
    owner_name: str = Field(..., min_length=2, max_length=255)
    mobile_number: str = Field(..., min_length=7, max_length=20)
    email: EmailStr
    gst_number: Optional[str] = Field(None, max_length=20)
    address: Optional[str] = None
    # Phase 11 (AUTH-004): caller may supply an initial admin password.
    # If omitted, a random secure password is generated and returned once.
    initial_password: Optional[str] = Field(None, min_length=8, max_length=72)


class CompanyResponse(BaseModel):
    id: uuid.UUID
    company_name: str
    owner_name: str
    mobile_number: str
    email: str
    gst_number: Optional[str] = None
    address: Optional[str] = None
    is_active: bool
    created_at: datetime
    # Phase 11: returned once on registration so caller knows the admin password.
    # Never stored — only present in the registration response.
    admin_email: Optional[str] = None
    admin_password: Optional[str] = None

    class Config:
        from_attributes = True


class CompanyDetailResponse(CompanyResponse):
    max_users: int
    max_vehicles: int
    subscription_tier: str
    user_count: int
    vehicle_count: int
