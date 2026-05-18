from pydantic import BaseModel
from typing import Optional


class DriverCreate(BaseModel):

    vehicle_id: Optional[int] = None

    full_name: str
    mobile_number: str

    license_number: str
    license_expiry: Optional[str] = None

    aadhaar_number: Optional[str] = None
    address: Optional[str] = None

    emergency_contact: Optional[str] = None

    # Phase 4: link driver to an auth.users account for self-attendance
    user_id: Optional[int] = None


class DriverUpdate(BaseModel):

    vehicle_id: Optional[int] = None

    full_name: Optional[str] = None
    mobile_number: Optional[str] = None

    license_number: Optional[str] = None
    license_expiry: Optional[str] = None

    aadhaar_number: Optional[str] = None
    address: Optional[str] = None

    emergency_contact: Optional[str] = None

    # Phase 4: link/unlink driver's user account
    user_id: Optional[int] = None


class DriverResponse(BaseModel):

    id: int

    vehicle_id: Optional[int] = None

    # Phase 4: expose linked user account ID
    user_id: Optional[int] = None

    full_name: str
    mobile_number: str

    license_number: str
    license_expiry: Optional[str] = None

    aadhaar_number: Optional[str] = None
    address: Optional[str] = None

    emergency_contact: Optional[str] = None

    # Operational status: OFF_DUTY | AVAILABLE | ON_TRIP | BREAK
    status: str = 'OFF_DUTY'

    class Config:
        from_attributes = True
