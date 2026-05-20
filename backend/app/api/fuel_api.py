"""
Fuel Management API — Phase 9.

Endpoints:
  POST   /fuel/                    Log fuel entry
  GET    /fuel/                    List entries (filters: vehicle_id, driver_id, trip_id)
  GET    /fuel/analytics           Fuel analytics summary
  GET    /fuel/{id}                Get single entry
  PUT    /fuel/{id}                Update entry
  DELETE /fuel/{id}                Delete entry
  GET    /fuel/vehicle/{vid}       Entries for a vehicle

All endpoints are tenant-isolated via filter_by_company().
"""

import logging
from datetime import datetime, date
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.fuel import FuelEntry
from app.models.vehicle import Vehicle
from app.models.driver import Driver
from app.schemas.fuel_schema import (
    FuelEntryCreate,
    FuelEntryUpdate,
    FuelEntryResponse,
    FuelAnalytics,
)
from app.api.dependencies import require_permission, get_current_tenant_user, get_db
from app.core.permissions import Permission
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company

logger = logging.getLogger(__name__)

router = APIRouter()


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _get_entry_or_404(entry_id: int, db: Session) -> FuelEntry:
    entry = (
        filter_by_company(db.query(FuelEntry), FuelEntry)
        .filter(FuelEntry.id == entry_id)
        .first()
    )
    if not entry:
        raise HTTPException(status_code=404, detail="Fuel entry not found.")
    return entry


def _enrich(entry: FuelEntry, db: Session) -> FuelEntryResponse:
    vehicle = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.id == entry.vehicle_id)
        .first()
    )
    driver = None
    if entry.driver_id:
        driver = (
            filter_by_company(db.query(Driver), Driver)
            .filter(Driver.id == entry.driver_id)
            .first()
        )
    return FuelEntryResponse(
        id=entry.id,
        company_id=str(entry.company_id) if entry.company_id else None,
        vehicle_id=entry.vehicle_id,
        vehicle_number=vehicle.vehicle_number if vehicle else None,
        driver_id=entry.driver_id,
        driver_name=driver.full_name if driver else None,
        trip_id=entry.trip_id,
        fuel_date=entry.fuel_date,
        quantity_litres=entry.quantity_litres,
        cost_per_litre=entry.cost_per_litre,
        total_cost=entry.total_cost,
        odometer_km=entry.odometer_km,
        fuel_station=entry.fuel_station,
        notes=entry.notes,
        created_by_user_id=entry.created_by_user_id,
        created_at=entry.created_at,
    )


# ─── Create ───────────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=FuelEntryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Log fuel entry",
)
def create_fuel_entry(
    data: FuelEntryCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_permission(Permission.MANAGE_FUEL)),
):
    company_id = TenantContext.get_company_id()

    # Validate vehicle
    vehicle = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.id == data.vehicle_id, Vehicle.is_active == True)
        .first()
    )
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found.")

    # Validate driver if provided
    if data.driver_id:
        driver = (
            filter_by_company(db.query(Driver), Driver)
            .filter(Driver.id == data.driver_id)
            .first()
        )
        if not driver:
            raise HTTPException(status_code=404, detail="Driver not found.")

    fuel_date = data.fuel_date or date.today()

    entry = FuelEntry(
        company_id=company_id,
        vehicle_id=data.vehicle_id,
        driver_id=data.driver_id,
        trip_id=data.trip_id,
        fuel_date=fuel_date,
        quantity_litres=data.quantity_litres,
        cost_per_litre=data.cost_per_litre,
        total_cost=data.total_cost,
        odometer_km=data.odometer_km,
        fuel_station=data.fuel_station,
        notes=data.notes,
        created_by_user_id=current_user.id,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)

    logger.info(
        "[fuel] Entry id=%d vehicle=%s qty=%.1fL cost=%.2f company=%s",
        entry.id, vehicle.vehicle_number,
        entry.quantity_litres, entry.total_cost or 0.0, company_id,
    )
    return _enrich(entry, db)


# ─── Analytics ────────────────────────────────────────────────────────────────

@router.get(
    "/analytics",
    response_model=FuelAnalytics,
    summary="Fuel analytics summary (company-scoped)",
)
def fuel_analytics(
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_FUEL)),
):
    q = filter_by_company(db.query(FuelEntry), FuelEntry)

    row = q.with_entities(
        func.count(FuelEntry.id),
        func.coalesce(func.sum(FuelEntry.quantity_litres), 0.0),
        func.coalesce(func.sum(FuelEntry.total_cost), 0.0),
        func.avg(FuelEntry.cost_per_litre),
        func.avg(FuelEntry.quantity_litres),
        func.count(func.distinct(FuelEntry.vehicle_id)),
    ).first()

    total_entries, total_litres, total_cost, avg_cpl, avg_lpf, vehicles = row

    return FuelAnalytics(
        total_entries=int(total_entries),
        total_litres=float(total_litres),
        total_cost=float(total_cost),
        avg_cost_per_litre=round(float(avg_cpl), 4) if avg_cpl else None,
        avg_litres_per_fill=round(float(avg_lpf), 2) if avg_lpf else None,
        vehicles_tracked=int(vehicles),
    )


# ─── List ─────────────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=List[FuelEntryResponse],
    summary="List fuel entries",
)
def list_fuel_entries(
    vehicle_id: Optional[int] = Query(None),
    driver_id: Optional[int] = Query(None),
    trip_id: Optional[int] = Query(None),
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_FUEL)),
):
    q = filter_by_company(db.query(FuelEntry), FuelEntry)

    if vehicle_id:
        q = q.filter(FuelEntry.vehicle_id == vehicle_id)
    if driver_id:
        q = q.filter(FuelEntry.driver_id == driver_id)
    if trip_id:
        q = q.filter(FuelEntry.trip_id == trip_id)

    entries = q.order_by(FuelEntry.fuel_date.desc(), FuelEntry.id.desc()).limit(limit).all()

    # Bulk-fetch vehicles and drivers to avoid N+1
    vehicle_ids = list({e.vehicle_id for e in entries})
    driver_ids  = list({e.driver_id for e in entries if e.driver_id})

    vehicles = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.id.in_(vehicle_ids)).all()
    ) if vehicle_ids else []
    drivers = (
        filter_by_company(db.query(Driver), Driver)
        .filter(Driver.id.in_(driver_ids)).all()
    ) if driver_ids else []

    vmap = {v.id: v.vehicle_number for v in vehicles}
    dmap = {d.id: d.full_name for d in drivers}

    return [
        FuelEntryResponse(
            id=e.id,
            company_id=str(e.company_id) if e.company_id else None,
            vehicle_id=e.vehicle_id,
            vehicle_number=vmap.get(e.vehicle_id),
            driver_id=e.driver_id,
            driver_name=dmap.get(e.driver_id) if e.driver_id else None,
            trip_id=e.trip_id,
            fuel_date=e.fuel_date,
            quantity_litres=e.quantity_litres,
            cost_per_litre=e.cost_per_litre,
            total_cost=e.total_cost,
            odometer_km=e.odometer_km,
            fuel_station=e.fuel_station,
            notes=e.notes,
            created_by_user_id=e.created_by_user_id,
            created_at=e.created_at,
        )
        for e in entries
    ]


# ─── Get single ───────────────────────────────────────────────────────────────

@router.get(
    "/{entry_id}",
    response_model=FuelEntryResponse,
    summary="Get fuel entry",
)
def get_fuel_entry(
    entry_id: int,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_FUEL)),
):
    return _enrich(_get_entry_or_404(entry_id, db), db)


# ─── Update ───────────────────────────────────────────────────────────────────

@router.put(
    "/{entry_id}",
    response_model=FuelEntryResponse,
    summary="Update fuel entry",
)
def update_fuel_entry(
    entry_id: int,
    data: FuelEntryUpdate,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.MANAGE_FUEL)),
):
    entry = _get_entry_or_404(entry_id, db)
    update_fields = data.model_dump(exclude_unset=True)
    for field, value in update_fields.items():
        setattr(entry, field, value)

    # Recompute total_cost if both are now known
    if entry.cost_per_litre and entry.quantity_litres and not data.total_cost:
        entry.total_cost = round(entry.quantity_litres * entry.cost_per_litre, 2)

    db.commit()
    db.refresh(entry)
    return _enrich(entry, db)


# ─── Delete ───────────────────────────────────────────────────────────────────

@router.delete(
    "/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete fuel entry",
)
def delete_fuel_entry(
    entry_id: int,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.MANAGE_FUEL)),
):
    entry = _get_entry_or_404(entry_id, db)
    db.delete(entry)
    db.commit()
    logger.info("[fuel] Deleted entry id=%d", entry_id)


# ─── By vehicle ───────────────────────────────────────────────────────────────

@router.get(
    "/vehicle/{vehicle_id}",
    response_model=List[FuelEntryResponse],
    summary="Fuel entries for a specific vehicle",
)
def list_by_vehicle(
    vehicle_id: int,
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_FUEL)),
):
    vehicle = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.id == vehicle_id)
        .first()
    )
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found.")

    entries = (
        filter_by_company(db.query(FuelEntry), FuelEntry)
        .filter(FuelEntry.vehicle_id == vehicle_id)
        .order_by(FuelEntry.fuel_date.desc())
        .limit(limit)
        .all()
    )

    return [
        FuelEntryResponse(
            id=e.id,
            company_id=str(e.company_id) if e.company_id else None,
            vehicle_id=e.vehicle_id,
            vehicle_number=vehicle.vehicle_number,
            driver_id=e.driver_id,
            trip_id=e.trip_id,
            fuel_date=e.fuel_date,
            quantity_litres=e.quantity_litres,
            cost_per_litre=e.cost_per_litre,
            total_cost=e.total_cost,
            odometer_km=e.odometer_km,
            fuel_station=e.fuel_station,
            notes=e.notes,
            created_at=e.created_at,
        )
        for e in entries
    ]
