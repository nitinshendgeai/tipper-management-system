"""
Pydantic schemas for Fuel Management — Phase 9.
"""

from pydantic import BaseModel, Field, model_validator
from typing import Optional, List
from datetime import date, datetime


class FuelEntryCreate(BaseModel):
    vehicle_id: int
    driver_id: Optional[int] = None
    trip_id: Optional[int] = None
    fuel_date: Optional[date] = None  # defaults to today if None
    quantity_litres: float = Field(..., gt=0, description="Litres filled — must be > 0")
    cost_per_litre: Optional[float] = Field(default=None, ge=0)
    total_cost: Optional[float] = Field(default=None, ge=0)
    odometer_km: Optional[float] = Field(default=None, ge=0)
    fuel_station: Optional[str] = Field(default=None, max_length=200)
    notes: Optional[str] = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def compute_total_cost(self) -> "FuelEntryCreate":
        """Auto-compute total_cost if cost_per_litre is provided and total_cost is absent."""
        if self.total_cost is None and self.cost_per_litre is not None:
            self.total_cost = round(self.quantity_litres * self.cost_per_litre, 2)
        return self


class FuelEntryUpdate(BaseModel):
    fuel_date: Optional[date] = None
    quantity_litres: Optional[float] = Field(default=None, gt=0)
    cost_per_litre: Optional[float] = Field(default=None, ge=0)
    total_cost: Optional[float] = Field(default=None, ge=0)
    odometer_km: Optional[float] = Field(default=None, ge=0)
    fuel_station: Optional[str] = Field(default=None, max_length=200)
    notes: Optional[str] = Field(default=None, max_length=500)
    driver_id: Optional[int] = None
    trip_id: Optional[int] = None


class FuelEntryResponse(BaseModel):
    id: int
    company_id: Optional[str] = None
    vehicle_id: int
    vehicle_number: Optional[str] = None  # enriched
    driver_id: Optional[int] = None
    driver_name: Optional[str] = None     # enriched
    trip_id: Optional[int] = None
    fuel_date: Optional[date] = None
    quantity_litres: float
    cost_per_litre: Optional[float] = None
    total_cost: Optional[float] = None
    odometer_km: Optional[float] = None
    fuel_station: Optional[str] = None
    notes: Optional[str] = None
    created_by_user_id: Optional[int] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class FuelAnalytics(BaseModel):
    """Lightweight fuel analytics summary — company-scoped."""
    total_entries: int
    total_litres: float
    total_cost: float
    avg_cost_per_litre: Optional[float]
    avg_litres_per_fill: Optional[float]
    vehicles_tracked: int
