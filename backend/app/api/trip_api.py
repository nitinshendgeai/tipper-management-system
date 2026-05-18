"""
Trip API — full operational lifecycle.

CREATED → STARTED → COMPLETED
CREATED → CANCELLED

Key design decisions:
  • Driver is AUTO-FETCHED from the vehicle's active DriverVehicleAssignment.
    Supervisors only select a vehicle when creating a trip.
  • Status transitions update vehicle.status and driver.status atomically.
  • All list responses return enriched TripListItem (vehicle_number, driver_name, etc.)
"""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.trip import Trip, TripStatus
from app.models.trip_expense import TripExpense
from app.models.assignment import DriverVehicleAssignment
from app.models.vehicle import Vehicle, VehicleStatus
from app.models.driver import Driver, DriverStatus
from app.models.route import Route

from app.schemas.trip_schema import (
    TripCreate,
    TripResponse,
    TripListItem,
    StartTripRequest,
    CompleteTripRequest,
    CancelTripRequest,
)

from app.api.dependencies import require_permission, get_current_tenant_user, get_db
from app.core.permissions import Permission
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company

# Phase 2 fix (DB-001): get_db() removed from local definition — imported from dependencies

router = APIRouter()


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _logged_expense_total(trip_id: int, db: Session) -> float:
    total = (
        db.query(func.coalesce(func.sum(TripExpense.amount), 0.0))
        .filter(TripExpense.trip_id == trip_id)
        .scalar()
    )
    return float(total or 0.0)


def _build_list_item(trip: Trip, db: Session) -> TripListItem:
    # Phase 3 fix: scope enrichment queries to company for defence-in-depth
    vehicle = filter_by_company(db.query(Vehicle), Vehicle).filter(Vehicle.id == trip.vehicle_id).first()
    driver  = filter_by_company(db.query(Driver), Driver).filter(Driver.id == trip.driver_id).first()
    route   = filter_by_company(db.query(Route), Route).filter(Route.id == trip.route_id).first() if trip.route_id else None

    route_label = None
    if route:
        route_label = f"{route.source_location} → {route.destination_location} ({route.distance_km} km)"

    return TripListItem(
        id=trip.id,
        trip_status=trip.trip_status,

        vehicle_id=trip.vehicle_id,
        vehicle_number=vehicle.vehicle_number if vehicle else "Unknown",
        vehicle_status=vehicle.status if vehicle else "UNKNOWN",

        driver_id=trip.driver_id,
        driver_name=driver.full_name if driver else "Unknown",
        driver_mobile=driver.mobile_number if driver else "",
        driver_status=driver.status if driver else "UNKNOWN",

        source_location=trip.source_location,
        destination_location=trip.destination_location,

        route_id=trip.route_id,
        route_label=route_label,

        calculated_distance_km=trip.calculated_distance_km,
        estimated_duration_min=trip.estimated_duration_min,
        estimated_diesel=trip.estimated_diesel,
        distance_km_override=trip.distance_km_override,

        trip_date=trip.trip_date,
        start_time=trip.start_time,
        end_time=trip.end_time,
        cancelled_at=trip.cancelled_at,
        cancellation_reason=trip.cancellation_reason,

        start_km=trip.start_km,
        end_km=trip.end_km,

        diesel_issued=trip.diesel_issued,
        diesel_used=trip.diesel_used,
        trip_advance=trip.trip_advance,
        trip_expense=trip.trip_expense,
        toll_expense=trip.toll_expense,
        driver_bata=trip.driver_bata,
        revenue_amount=trip.revenue_amount,

        total_logged_expense=_logged_expense_total(trip.id, db),

        remarks=trip.remarks,
        created_at=trip.created_at,
    )


# ─── CREATE TRIP ──────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=TripResponse,
    summary="Create a new trip — driver is auto-fetched from vehicle assignment (SUPERVISOR or above)"
)
def create_trip(
    data: TripCreate,
    current_user=Depends(require_permission(Permission.CREATE_TRIPS)),
    db: Session = Depends(get_db)
):
    # 1. Validate vehicle (scoped to company)
    vehicle = filter_by_company(
        db.query(Vehicle), Vehicle
    ).filter(
        Vehicle.id == data.vehicle_id,
        Vehicle.is_active == True
    ).first()

    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    if vehicle.status == VehicleStatus.ON_TRIP:
        raise HTTPException(
            status_code=409,
            detail=f"Vehicle {vehicle.vehicle_number} is already ON_TRIP"
        )

    if vehicle.status == VehicleStatus.MAINTENANCE:
        raise HTTPException(
            status_code=409,
            detail=f"Vehicle {vehicle.vehicle_number} is under MAINTENANCE"
        )

    # 2. Auto-fetch driver from active assignment (scoped to company)
    assignment = filter_by_company(
        db.query(DriverVehicleAssignment), DriverVehicleAssignment
    ).filter(
        DriverVehicleAssignment.vehicle_id == data.vehicle_id,
        DriverVehicleAssignment.is_active == True
    ).first()

    if not assignment:
        raise HTTPException(
            status_code=409,
            detail=f"Vehicle {vehicle.vehicle_number} has no active driver assignment. Assign a driver first."
        )

    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(
        Driver.id == assignment.driver_id,
        Driver.is_active == True
    ).first()

    if not driver:
        raise HTTPException(status_code=404, detail="Assigned driver not found or inactive")

    if driver.status == DriverStatus.ON_TRIP:
        raise HTTPException(
            status_code=409,
            detail=f"Driver {driver.full_name} is already ON_TRIP"
        )

    # 3. Validate optional route (scoped to company)
    if data.route_id:
        route = filter_by_company(
            db.query(Route), Route
        ).filter(
            Route.id == data.route_id,
            Route.is_active == True
        ).first()
        if not route:
            raise HTTPException(status_code=404, detail="Route not found")

    # 4. Create trip
    trip = Trip(
        company_id=current_user.company_id,
        vehicle_id=data.vehicle_id,
        driver_id=driver.id,
        route_id=data.route_id,
        source_location=data.source_location,
        destination_location=data.destination_location,
        calculated_distance_km=data.calculated_distance_km,
        estimated_duration_min=data.estimated_duration_min,
        estimated_diesel=data.estimated_diesel,
        distance_km_override=data.distance_km_override,
        diesel_issued=data.diesel_issued,
        trip_advance=data.trip_advance,
        remarks=data.remarks,
        trip_status=TripStatus.CREATED,
    )

    db.add(trip)
    db.commit()
    db.refresh(trip)

    return trip


# ─── READ ALL ─────────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=list[TripListItem],
    summary="List trips — optionally filtered by status"
)
def list_trips(
    status: str = Query(default=None, description="CREATED | STARTED | COMPLETED | CANCELLED"),
    vehicle_id: int = Query(default=None),
    driver_id: int = Query(default=None),
    current_user=Depends(require_permission(Permission.VIEW_TRIPS)),
    db: Session = Depends(get_db)
):
    query = filter_by_company(db.query(Trip), Trip)

    # Phase 4 fix: DRIVER role can only see their own trips.
    # Resolve the driver profile via user_id link (set by MANAGER when creating driver).
    role_name = TenantContext.get_role_name()
    if role_name == "DRIVER":
        driver_profile = filter_by_company(
            db.query(Driver), Driver
        ).filter(
            Driver.user_id == current_user.id,
            Driver.is_active == True,
        ).first()
        if driver_profile:
            query = query.filter(Trip.driver_id == driver_profile.id)
        else:
            # No driver profile linked to this user account — return empty
            return []

    if status:
        query = query.filter(Trip.trip_status == status.upper())

    if vehicle_id:
        query = query.filter(Trip.vehicle_id == vehicle_id)

    if driver_id:
        query = query.filter(Trip.driver_id == driver_id)

    trips = query.order_by(Trip.created_at.desc()).all()

    return [_build_list_item(t, db) for t in trips]


# ─── READ ONE ─────────────────────────────────────────────────────────────────

@router.get(
    "/{trip_id}",
    response_model=TripListItem,
    summary="Get a single trip by ID"
)
def get_trip(
    trip_id: int,
    current_user=Depends(require_permission(Permission.VIEW_TRIPS)),
    db: Session = Depends(get_db)
):
    trip = filter_by_company(
        db.query(Trip), Trip
    ).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    return _build_list_item(trip, db)


# ─── START TRIP ───────────────────────────────────────────────────────────────

@router.put(
    "/{trip_id}/start",
    response_model=TripListItem,
    summary="Start a trip — CREATED → STARTED (SUPERVISOR or above)"
)
def start_trip(
    trip_id: int,
    data: StartTripRequest,
    current_user=Depends(require_permission(Permission.MANAGE_TRIPS)),
    db: Session = Depends(get_db)
):
    trip = filter_by_company(
        db.query(Trip), Trip
    ).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if trip.trip_status != TripStatus.CREATED:
        raise HTTPException(
            status_code=409,
            detail=f"Trip cannot be started — current status is '{trip.trip_status}'"
        )

    vehicle = filter_by_company(db.query(Vehicle), Vehicle).filter(Vehicle.id == trip.vehicle_id).first()
    driver  = filter_by_company(db.query(Driver), Driver).filter(Driver.id == trip.driver_id).first()

    trip.trip_status = TripStatus.STARTED
    trip.start_time  = datetime.utcnow()
    trip.start_km    = data.start_km

    if vehicle:
        vehicle.status = VehicleStatus.ON_TRIP

    if driver:
        driver.status = DriverStatus.ON_TRIP

    db.commit()
    db.refresh(trip)

    return _build_list_item(trip, db)


# ─── COMPLETE TRIP ─────────────────────────────────────────────────────────────

@router.put(
    "/{trip_id}/complete",
    response_model=TripListItem,
    summary="Complete a trip — STARTED → COMPLETED (SUPERVISOR or above)"
)
def complete_trip(
    trip_id: int,
    data: CompleteTripRequest,
    current_user=Depends(require_permission(Permission.MANAGE_TRIPS)),
    db: Session = Depends(get_db)
):
    trip = filter_by_company(
        db.query(Trip), Trip
    ).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if trip.trip_status != TripStatus.STARTED:
        raise HTTPException(
            status_code=409,
            detail=f"Trip cannot be completed — current status is '{trip.trip_status}'"
        )

    if trip.start_km is not None and data.end_km <= trip.start_km:
        raise HTTPException(
            status_code=422,
            detail=f"End KM ({data.end_km}) must be greater than Start KM ({trip.start_km})"
        )

    vehicle = filter_by_company(db.query(Vehicle), Vehicle).filter(Vehicle.id == trip.vehicle_id).first()
    driver  = filter_by_company(db.query(Driver), Driver).filter(Driver.id == trip.driver_id).first()

    trip.trip_status    = TripStatus.COMPLETED
    trip.end_time       = datetime.utcnow()
    trip.end_km         = data.end_km
    trip.diesel_used    = data.diesel_used
    trip.revenue_amount = data.revenue_amount

    if data.remarks:
        trip.remarks = data.remarks

    # Compute total expense from logged expenses
    logged_total = _logged_expense_total(trip_id, db)
    if logged_total > 0:
        trip.trip_expense = logged_total

    # Release vehicle — back to ASSIGNED if still has active assignment, else AVAILABLE
    if vehicle:
        still_assigned = filter_by_company(
            db.query(DriverVehicleAssignment), DriverVehicleAssignment
        ).filter(
            DriverVehicleAssignment.vehicle_id == vehicle.id,
            DriverVehicleAssignment.is_active == True
        ).first()

        vehicle.status = VehicleStatus.ASSIGNED if still_assigned else VehicleStatus.AVAILABLE

    # Release driver — back to AVAILABLE (on shift)
    if driver:
        driver.status = DriverStatus.AVAILABLE

    db.commit()
    db.refresh(trip)

    return _build_list_item(trip, db)


# ─── CANCEL TRIP ───────────────────────────────────────────────────────────────

@router.put(
    "/{trip_id}/cancel",
    response_model=TripListItem,
    summary="Cancel a trip — only CREATED trips can be cancelled (SUPERVISOR or above)"
)
def cancel_trip(
    trip_id: int,
    data: CancelTripRequest,
    current_user=Depends(require_permission(Permission.MANAGE_TRIPS)),
    db: Session = Depends(get_db)
):
    trip = filter_by_company(
        db.query(Trip), Trip
    ).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if trip.trip_status not in (TripStatus.CREATED,):
        raise HTTPException(
            status_code=409,
            detail=f"Only CREATED trips can be cancelled (current: {trip.trip_status})"
        )

    vehicle = filter_by_company(db.query(Vehicle), Vehicle).filter(Vehicle.id == trip.vehicle_id).first()
    driver  = filter_by_company(db.query(Driver), Driver).filter(Driver.id == trip.driver_id).first()

    trip.trip_status         = TripStatus.CANCELLED
    trip.cancelled_at        = datetime.utcnow()
    trip.cancellation_reason = data.cancellation_reason

    # Restore vehicle to ASSIGNED (assignment still active)
    if vehicle and vehicle.status != VehicleStatus.ON_TRIP:
        still_assigned = filter_by_company(
            db.query(DriverVehicleAssignment), DriverVehicleAssignment
        ).filter(
            DriverVehicleAssignment.vehicle_id == vehicle.id,
            DriverVehicleAssignment.is_active == True
        ).first()
        vehicle.status = VehicleStatus.ASSIGNED if still_assigned else VehicleStatus.AVAILABLE

    # Driver stays AVAILABLE
    if driver and driver.status != DriverStatus.ON_TRIP:
        driver.status = DriverStatus.AVAILABLE

    db.commit()
    db.refresh(trip)

    return _build_list_item(trip, db)
