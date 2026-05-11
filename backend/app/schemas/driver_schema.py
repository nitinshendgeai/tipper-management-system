from pydantic import BaseModel
from typing import Optional


class DriverCreate(BaseModel):

    vehicle_id: Optional[int] = None

    full_name: str
    mobile_number: str

    license_number: str
    license_expiry: str

    aadhaar_number: str
    address: str

    emergency_contact: str


class DriverUpdate(BaseModel):

    vehicle_id: Optional[int] = None

    full_name: Optional[str] = None
    mobile_number: Optional[str] = None

    license_number: Optional[str] = None
    license_expiry: Optional[str] = None

    aadhaar_number: Optional[str] = None
    address: Optional[str] = None

    emergency_contact: Optional[str] = None


class DriverResponse(BaseModel):

    id: int

    vehicle_id: Optional[int] = None

    full_name: str
    mobile_number: str

    license_number: str
    license_expiry: str

    aadhaar_number: str
    address: str

    emergency_contact: str

    # Operational status: OFF_DUTY | AVAILABLE | ON_TRIP | BREAK
    status: str = 'OFF_DUTY'

    class Config:
        from_attributes = True
