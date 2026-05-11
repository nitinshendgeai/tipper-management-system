from fastapi import (
    APIRouter,
    Depends,
    HTTPException
)

from sqlalchemy.orm import Session

from app.db.session import SessionLocal

from app.models.driver import Driver

from app.schemas.driver_schema import (
    DriverCreate,
    DriverUpdate,
    DriverResponse
)

from app.api.role_checker import RoleChecker


admin_manager = RoleChecker([1])

router = APIRouter()


def get_db():

    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()


# ─── CREATE ───────────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=DriverResponse,
    summary="Create a new driver (admin only)"
)
def create_driver(
    data: DriverCreate,
    current_user=Depends(admin_manager),
    db: Session = Depends(get_db)
):

    existing_driver = db.query(Driver).filter(
        Driver.license_number == data.license_number
    ).first()

    if existing_driver:

        raise HTTPException(
            status_code=400,
            detail="Driver with this license number already exists"
        )

    driver = Driver(
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
    db: Session = Depends(get_db)
):

    drivers = db.query(Driver).filter(Driver.is_active == True).all()

    return drivers


# ─── READ ONE ─────────────────────────────────────────────────────────────────

@router.get(
    "/{driver_id}",
    response_model=DriverResponse,
    summary="Get a single driver by ID"
)
def get_driver(
    driver_id: int,
    db: Session = Depends(get_db)
):

    driver = db.query(Driver).filter(
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
    summary="Update a driver (admin only)"
)
def update_driver(
    driver_id: int,
    data: DriverUpdate,
    current_user=Depends(admin_manager),
    db: Session = Depends(get_db)
):

    driver = db.query(Driver).filter(
        Driver.id == driver_id,
        Driver.is_active == True
    ).first()

    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")

    # Guard against duplicate license number when changing it
    if data.license_number and data.license_number != driver.license_number:

        existing = db.query(Driver).filter(
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
    summary="Soft-delete a driver (admin only)"
)
def delete_driver(
    driver_id: int,
    current_user=Depends(admin_manager),
    db: Session = Depends(get_db)
):

    driver = db.query(Driver).filter(
        Driver.id == driver_id,
        Driver.is_active == True
    ).first()

    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")

    # Soft delete — preserves trip history referencing this driver
    driver.is_active = False
    db.commit()

    return {"message": f"Driver {driver.full_name} deleted successfully"}
