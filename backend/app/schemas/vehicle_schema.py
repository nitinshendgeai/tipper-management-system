from pydantic import BaseModel
from typing import Optional


class VehicleCreate(BaseModel):

    vehicle_number: str
    vehicle_type: str
    capacity_ton: int
    owner_name: str
    mobile_number: str
    rc_number: str
    insurance_expiry: str


class VehicleUpdate(BaseModel):

    vehicle_number: Optional[str] = None
    vehicle_type: Optional[str] = None
    capacity_ton: Optional[int] = None
    owner_name: Optional[str] = None
    mobile_number: Optional[str] = None
    rc_number: Optional[str] = None
    insurance_expiry: Optional[str] = None


class VehicleResponse(BaseModel):

    id: int
    vehicle_number: str
    vehicle_type: str
    capacity_ton: int
    owner_name: str
    mobile_number: str
    rc_number: str
    insurance_expiry: str

    # Operational status: AVAILABLE | ASSIGNED | ON_TRIP | MAINTENANCE
    status: str = 'AVAILABLE'

    class Config:
        from_attributes = True
