from fastapi import (
    APIRouter,
    Depends,
    HTTPException
)

from sqlalchemy.orm import Session

from app.models.driver import Driver

from app.schemas.driver_schema import (
    DriverCreate,
    DriverUpdate,
    DriverResponse
)

from app.api.dependencies import require_permission, get_db
from app.core.permissions import Permission
from app.db.tenant_queries import filter_by_company

# Phase 3 cleanup (DB-001): get_db() imported from dependencies — local copy removed

router = APIRouter()


# ─── CREATE ───────────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=DriverResponse,
    summary="Create a new driver (MANAGER or above)"
)
def create_driver(
    data: DriverCreate,
    current_user=Depends(require_permission(Permission.MANAGE_DRIVERS)),
    db: Session = Depends(get_db)
):

    existing_driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(
        Driver.license_number == data.license_number
    ).first()

    if existing_driver:

        raise HTTPException(
            status_code=400,
            detail="Driver with this license number already exists"
        )

    driver = Driver(
        company_id=current_user.company_id,
        vehicle_id=data.vehicle_id,
        full_name=data.full_name,
        mobile_number=data.mobile_number,
        license_number=data.license_number,
        license_expiry=data.license_expiry,
        aadhaar_number=data.aadhaar_number,
        address=data.address,
        emergency_contact=data.emergency_contact
    )

    db.add(driver)
    db.commit()
    db.refresh(driver)

    return driver


# ─── READ ALL ─────────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=list[DriverResponse],
    summary="List all active drivers"
)
def list_drivers(
    current_user=Depends(require_permission(Permission.VIEW_DRIVERS)),
    db: Session = Depends(get_db)
):

    drivers = filter_by_company(
        db.query(Driver), Driver
    ).filter(Driver.is_active == True).all()

    return drivers


# ─── READ ONE ─────────────────────────────────────────────────────────────────

@router.get(
    "/{driver_id}",
    response_model=DriverResponse,
    summary="Get a single driver by ID"
)
def get_driver(
    driver_id: int,
    current_user=Depends(require_permission(Permission.VIEW_DRIVERS)),
    db: Session = Depends(get_db)
):

    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(
        Driver.id == driver_id,
        Driver.is_active == True
    ).first()

    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")

    return driver


# ─── UPDATE ───────────────────────────────────────────────────────────────────

@router.put(
    "/{driver_id}",
    response_model=DriverResponse,
    summary="Update a driver (MANAGER or above)"
)
def update_driver(
    driver_id: int,
    data: DriverUpdate,
    current_user=Depends(require_permission(Permission.MANAGE_DRIVERS)),
    db: Session = Depends(get_db)
):

    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(
        Driver.id == driver_id,
        Driver.is_active == True
    ).first()

    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")

    # Guard against duplicate license number when changing it
    if data.license_number and data.license_number != driver.license_number:

        existing = filter_by_company(
            db.query(Driver), Driver
        ).filter(
            Driver.license_number == data.license_number
        ).first()

        if existing:
            raise HTTPException(
                status_code=400,
                detail="License number already in use by another driver"
            )

    update_data = data.dict(exclude_unset=True)

    for key, value in update_data.items():
        setattr(driver, key, value)

    db.commit()
    db.refresh(driver)

    return driver


# ─── DELETE (soft) ────────────────────────────────────────────────────────────

@router.delete(
    "/{driver_id}",
    summary="Soft-delete a driver (MANAGER or above)"
)
def delete_driver(
    driver_id: int,
    current_user=Depends(require_permission(Permission.MANAGE_DRIVERS)),
    db: Session = Depends(get_db)
):

    driver = filter_by_company(
        db.query(Driver), Driver
    ).filter(
        Driver.id == driver_id,
        Driver.is_active == True
    ).first()

    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")

    # Soft delete — preserves trip history referencing this driver
    driver.is_active = False
    db.commit()

    return {"message": f"Driver {driver.full_name} deleted successfully"}
