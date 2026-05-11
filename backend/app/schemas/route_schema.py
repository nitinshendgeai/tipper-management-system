from pydantic import BaseModel
from typing import Optional


class RouteCreate(BaseModel):

    source_location: str
    destination_location: str

    distance_km: float

    # Optional operational fields — used by trip planning, not required on form
    trip_rate: Optional[float] = None
    diesel_limit: Optional[float] = None
    estimated_hours: Optional[float] = None

    # Optional free-text notes
    remarks: Optional[str] = None


class RouteUpdate(BaseModel):

    source_location: Optional[str] = None
    destination_location: Optional[str] = None

    distance_km: Optional[float] = None

    trip_rate: Optional[float] = None
    diesel_limit: Optional[float] = None
    estimated_hours: Optional[float] = None

    remarks: Optional[str] = None


class RouteResponse(BaseModel):

    id: int

    source_location: str
    destination_location: str

    distance_km: Optional[float] = None

    trip_rate: Optional[float] = None
    diesel_limit: Optional[float] = None
    estimated_hours: Optional[float] = None

    remarks: Optional[str] = None

    class Config:
        from_attributes = True
