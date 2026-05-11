from pydantic import BaseModel
from typing import Optional
from datetime import datetime


# ─── CREATE ───────────────────────────────────────────────────────────────────

class TripCreate(BaseModel):
    """
    Supervisor creates a trip by selecting a vehicle.
    Driver is AUTO-FETCHED from the vehicle's active assignment.
    Source/destination are free-text (AI calculates distance/duration).
    route_id is optional — for reference to a saved route master record.
    """

    vehicle_id: int

    source_location: str
    destination_location: str

    route_id: Optional[int] = None

    # AI-calculated fields (sent back from /route-intelligence/calculate)
    calculated_distance_km: Optional[float] = None
    estimated_duration_min: Optional[int] = None
    estimated_diesel: Optional[float] = None

    # Supervisor can manually override the AI distance
    distance_km_override: Optional[float] = None

    diesel_issued: Optional[float] = None
    trip_advance: Optional[float] = None
    remarks: Optional[str] = None


# ─── START ────────────────────────────────────────────────────────────────────

class StartTripRequest(BaseModel):

    start_km: float


# ─── COMPLETE ─────────────────────────────────────────────────────────────────

class CompleteTripRequest(BaseModel):

    end_km: float
    diesel_used: float
    revenue_amount: Optional[float] = None
    remarks: Optional[str] = None


# ─── CANCEL ───────────────────────────────────────────────────────────────────

class CancelTripRequest(BaseModel):

    cancellation_reason: Optional[str] = None


# ─── ENRICHED RESPONSE (list + detail) ────────────────────────────────────────

class TripListItem(BaseModel):

    id: int
    trip_status: str

    vehicle_id: int
    vehicle_number: str
    vehicle_status: str

    driver_id: int
    driver_name: str
    driver_mobile: str
    driver_status: str

    source_location: Optional[str] = None
    destination_location: Optional[str] = None

    route_id: Optional[int] = None
    route_label: Optional[str] = None       # "Source → Destination (km)"

    calculated_distance_km: Optional[float] = None
    estimated_duration_min: Optional[int] = None
    estimated_diesel: Optional[float] = None
    distance_km_override: Optional[float] = None

    trip_date: Optional[datetime] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None
    cancellation_reason: Optional[str] = None

    start_km: Optional[float] = None
    end_km: Optional[float] = None

    diesel_issued: Optional[float] = None
    diesel_used: Optional[float] = None
    trip_advance: Optional[float] = None
    trip_expense: Optional[float] = None
    toll_expense: Optional[float] = None
    driver_bata: Optional[float] = None
    revenue_amount: Optional[float] = None

    # Computed totals from trip_expenses table
    total_logged_expense: Optional[float] = None

    remarks: Optional[str] = None
    created_at: Optional[datetime] = None


# ─── RAW CREATE RESPONSE ──────────────────────────────────────────────────────

class TripResponse(BaseModel):
    """Minimal response returned immediately after trip creation."""

    id: int
    vehicle_id: int
    driver_id: int
    route_id: Optional[int] = None
    source_location: Optional[str] = None
    destination_location: Optional[str] = None
    trip_status: str
    calculated_distance_km: Optional[float] = None
    estimated_duration_min: Optional[int] = None
    estimated_diesel: Optional[float] = None
    distance_km_override: Optional[float] = None
    diesel_issued: Optional[float] = None
    trip_advance: Optional[float] = None
    remarks: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
