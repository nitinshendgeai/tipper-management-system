"""
Allocation API — Driver ↔ Vehicle shift assignment.

Business rules:
  • One active assignment per vehicle (409 if vehicle already assigned)
  • One active assignment per driver  (409 if driver already assigned)
  • Creating assignment → vehicle.status = ASSIGNED, driver.status = AVAILABLE
  • Releasing assignment → vehicle.status = AVAILABLE, driver.status = OFF_DUTY
    (only if vehicle is not currently ON_TRIP)
"""

from datetime import datetime, date

from fastapi import APIRouter, Depends, HTTPException

from sqlalchemy.orm import Session

from app.models.assignment import DriverVehicleAssignment
from app.models.vehicle import Vehicle, VehicleStatus
from app.models.driver import Driver, DriverStatus
from app.models.user import User

from app.schemas.assignment_schema import (
    AssignmentCreate,
    AssignmentRelease,
    AssignmentResponse,
    AssignmentDetail,
    VehicleAssignmentStatus,
)

from app.api.dependencies import require_permission, get_db
from app.core.permissions import Permission
from app.db.tenant_queries import filter_by_company

# Phase 3 cleanup (DB-001): get_db() imported from dependencies — local copy removed

router = APIRouter()


# ─── Helper ───────────────────────────────────────────────────────────────────

def _enrich(assignment: DriverVehicleAssignment, db: Session) -> AssignmentDetail:
    # Phase 3 fix: use filter_by_company() on enrichment queries for defence-in-depth.
    # The assignment is already company-scoped, but explicit filters prevent any
    # future regression from returning cross-tenant vehicle/driver rows.
    vehicle = filter_by_company(db.query(Vehicle), Vehicle).filter(Vehicle.id == assignment.vehicle_id).first()
    driver  = filter_by_company(db.query(Driver), Driver).filter(Driver.id == assignment.driver_id).first()
    # User lookup is company-scoped via company_id on the User model
    user    = db.query(User).filter(User.id == assignment.assigned_by, User.company_id == assignment.company_id).first() if assignment.assigned_by else None

    return AssignmentDetail(
        id=assignment.id,
        vehicle_id=assignment.vehicle_id,
        vehicle_number=vehicle.vehicle_number if vehicle else "Unknown",
        vehicle_type=vehicle.vehicle_type if vehicle else None,
        vehicle_status=vehicle.status if vehicle else "UNKNOWN",
        driver_id=assignment.driver_id,
        driver_name=driver.full_name if driver else "Unknown",
        driver_mobile=driver.mobile_number if driver else "",
        driver_status=driver.status if driver else "UNKNOWN",
        assigned_by=assignment.assigned_by,
        assigned_by_name=user.full_name if user else None,
        assigned_at=assignment.assigned_at,
        shift_date=assignment.shift_date,
        released_at=assignment.released_at,
        remarks=assignment.remarks,
        is_active=assignment.is_active,
    )


# ─── CREATE ASSIGNMENT ────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=AssignmentDetail,
    summary="Assign a driver to a vehicle for a shift (SUPERVISOR or above)"
)
def create_assignment(
    data: AssignmentCreate,
    current_user=Depends(require_permission(Permission.MANAGE_TRIPS)),
    db: Session = Depends(get_db)
):
    # Validate vehicle (scoped to company)
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
            detail=f"Vehicle {vehicle.vehicle_number} is currently ON_TRIP — cannot reassign"
        )

    # Validate driver (scoped to company)
    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(
        Driver.id == data.driver_id,
        Driver.is_active == True
    ).first()

    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")

    # One active assignment per vehicle (scoped to company)
    existing_vehicle_assignment = filter_by_company(
        db.query(DriverVehicleAssignment), DriverVehicleAssignment
    ).filter(
        DriverVehicleAssignment.vehicle_id == data.vehicle_id,
        DriverVehicleAssignment.is_active == True
    ).first()

    if existing_vehicle_assignment:
        raise HTTPException(
            status_code=409,
            detail=f"Vehicle {vehicle.vehicle_number} already has an active assignment (Assignment #{existing_vehicle_assignment.id})"
        )

    # One active assignment per driver (scoped to company)
    existing_driver_assignment = filter_by_company(
        db.query(DriverVehicleAssignment), DriverVehicleAssignment
    ).filter(
        DriverVehicleAssignment.driver_id == data.driver_id,
        DriverVehicleAssignment.is_active == True
    ).first()

    if existing_driver_assignment:
        raise HTTPException(
            status_code=409,
            detail=f"Driver {driver.full_name} is already assigned to another vehicle (Assignment #{existing_driver_assignment.id})"
        )

    # Create assignment
    assignment = DriverVehicleAssignment(
        company_id=current_user.company_id,
        vehicle_id=data.vehicle_id,
        driver_id=data.driver_id,
        assigned_by=current_user.id,
        assigned_at=datetime.utcnow(),
        shift_date=data.shift_date or date.today(),
        remarks=data.remarks,
        is_active=True,
    )

    db.add(assignment)

    # Update statuses
    vehicle.status = VehicleStatus.ASSIGNED
    driver.status  = DriverStatus.AVAILABLE

    db.commit()
    db.refresh(assignment)

    return _enrich(assignment, db)


# ─── LIST ALL ACTIVE ASSIGNMENTS ──────────────────────────────────────────────

@router.get(
    "/active",
    response_model=list[AssignmentDetail],
    summary="List all currently active shift assignments"
)
def list_active_assignments(
    current_user=Depends(require_permission(Permission.VIEW_TRIPS)),
    db: Session = Depends(get_db)
):
    assignments = (
        filter_by_company(db.query(DriverVehicleAssignment), DriverVehicleAssignment)
        .filter(DriverVehicleAssignment.is_active == True)
        .order_by(DriverVehicleAssignment.assigned_at.desc())
        .all()
    )

    return [_enrich(a, db) for a in assignments]


# ─── LIST ALL ASSIGNMENTS (history) ──────────────────────────────────────────

@router.get(
    "/",
    response_model=list[AssignmentDetail],
    summary="List all assignments (active + historical)"
)
def list_all_assignments(
    current_user=Depends(require_permission(Permission.VIEW_TRIPS)),
    db: Session = Depends(get_db)
):
    assignments = (
        filter_by_company(db.query(DriverVehicleAssignment), DriverVehicleAssignment)
        .order_by(DriverVehicleAssignment.assigned_at.desc())
        .all()
    )

    return [_enrich(a, db) for a in assignments]


# ─── GET ASSIGNMENT BY ID ─────────────────────────────────────────────────────

@router.get(
    "/{assignment_id}",
    response_model=AssignmentDetail,
    summary="Get assignment by ID"
)
def get_assignment(
    assignment_id: int,
    current_user=Depends(require_permission(Permission.VIEW_TRIPS)),
    db: Session = Depends(get_db)
):
    assignment = filter_by_company(
        db.query(DriverVehicleAssignment), DriverVehicleAssignment
    ).filter(
        DriverVehicleAssignment.id == assignment_id
    ).first()

    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    return _enrich(assignment, db)


# ─── GET ACTIVE ASSIGNMENT BY VEHICLE ────────────────────────────────────────

@router.get(
    "/vehicle/{vehicle_id}/status",
    response_model=VehicleAssignmentStatus,
    summary="Get current assignment status for a vehicle"
)
def get_vehicle_assignment_status(
    vehicle_id: int,
    current_user=Depends(require_permission(Permission.VIEW_TRIPS)),
    db: Session = Depends(get_db)
):
    vehicle = filter_by_company(
        db.query(Vehicle), Vehicle
    ).filter(
        Vehicle.id == vehicle_id,
        Vehicle.is_active == True
    ).first()

    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    assignment = filter_by_company(
        db.query(DriverVehicleAssignment), DriverVehicleAssignment
    ).filter(
        DriverVehicleAssignment.vehicle_id == vehicle_id,
        DriverVehicleAssignment.is_active == True
    ).first()

    if not assignment:
        return VehicleAssignmentStatus(
            vehicle_id=vehicle.id,
            vehicle_number=vehicle.vehicle_number,
            vehicle_status=vehicle.status,
            is_assigned=False,
        )

    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(Driver.id == assignment.driver_id).first()

    return VehicleAssignmentStatus(
        vehicle_id=vehicle.id,
        vehicle_number=vehicle.vehicle_number,
        vehicle_status=vehicle.status,
        is_assigned=True,
        assignment_id=assignment.id,
        driver_id=driver.id if driver else None,
        driver_name=driver.full_name if driver else None,
        driver_mobile=driver.mobile_number if driver else None,
        driver_status=driver.status if driver else None,
        shift_date=assignment.shift_date,
    )


# ─── RELEASE ASSIGNMENT ───────────────────────────────────────────────────────

@router.put(
    "/{assignment_id}/release",
    response_model=AssignmentDetail,
    summary="End a shift — release driver from vehicle (SUPERVISOR or above)"
)
def release_assignment(
    assignment_id: int,
    data: AssignmentRelease,
    current_user=Depends(require_permission(Permission.MANAGE_TRIPS)),
    db: Session = Depends(get_db)
):
    assignment = filter_by_company(
        db.query(DriverVehicleAssignment), DriverVehicleAssignment
    ).filter(
        DriverVehicleAssignment.id == assignment_id,
        DriverVehicleAssignment.is_active == True
    ).first()

    if not assignment:
        raise HTTPException(
            status_code=404,
            detail="Active assignment not found"
        )

    vehicle = filter_by_company(db.query(Vehicle), Vehicle).filter(Vehicle.id == assignment.vehicle_id).first()
    driver  = filter_by_company(db.query(Driver), Driver).filter(Driver.id == assignment.driver_id).first()

    if vehicle and vehicle.status == VehicleStatus.ON_TRIP:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot release assignment — vehicle {vehicle.vehicle_number} is currently ON_TRIP"
        )

    if driver and driver.status == DriverStatus.ON_TRIP:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot release assignment — driver {driver.full_name} is currently ON_TRIP"
        )

    # Release
    assignment.is_active  = False
    assignment.released_at = datetime.utcnow()

    if data.remarks:
        assignment.remarks = data.remarks

    # Reset statuses
    if vehicle:
        vehicle.status = VehicleStatus.AVAILABLE

    if driver:
        driver.status = DriverStatus.OFF_DUTY

    db.commit()
    db.refresh(assignment)

    return _enrich(assignment, db)
