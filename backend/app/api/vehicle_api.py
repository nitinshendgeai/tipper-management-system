from fastapi import (
    APIRouter,
    Depends,
    HTTPException
)

from sqlalchemy.orm import Session

from app.db.session import SessionLocal

from app.models.vehicle import Vehicle

from app.schemas.vehicle_schema import (
    VehicleCreate,
    VehicleUpdate,
    VehicleResponse
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


@router.post(
    "/",
    response_model=VehicleResponse
)
def create_vehicle(
    data: VehicleCreate,
    current_user=Depends(admin_manager),
    db: Session = Depends(get_db)
):

    existing_vehicle = db.query(Vehicle).filter(
        Vehicle.vehicle_number == data.vehicle_number
    ).first()

    if existing_vehicle:

        raise HTTPException(
            status_code=400,
            detail="Vehicle already exists"
        )

    vehicle = Vehicle(
        vehicle_number=data.vehicle_number,
        vehicle_type=data.vehicle_type,
        capacity_ton=data.capacity_ton,
        owner_name=data.owner_name,
        mobile_number=data.mobile_number,
        rc_number=data.rc_number,
        insurance_expiry=data.insurance_expiry
    )

    db.add(vehicle)
    db.commit()
    db.refresh(vehicle)

    return vehicle


@router.get(
    "/",
    response_model=list[VehicleResponse]
)
def list_vehicles(
    db: Session = Depends(get_db)
):

    vehicles = db.query(Vehicle).filter(Vehicle.is_active == True).all()

    return vehicles


@router.get(
    "/{vehicle_id}",
    response_model=VehicleResponse
)
def get_vehicle(
    vehicle_id: int,
    db: Session = Depends(get_db)
):

    vehicle = db.query(Vehicle).filter(
        Vehicle.id == vehicle_id,
        Vehicle.is_active == True
    ).first()

    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    return vehicle


@router.put(
    "/{vehicle_id}",
    response_model=VehicleResponse
)
def update_vehicle(
    vehicle_id: int,
    data: VehicleUpdate,
    current_user=Depends(admin_manager),
    db: Session = Depends(get_db)
):

    vehicle = db.query(Vehicle).filter(
        Vehicle.id == vehicle_id,
        Vehicle.is_active == True
    ).first()

    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    # Check for duplicate vehicle_number if being changed
    if data.vehicle_number and data.vehicle_number != vehicle.vehicle_number:

        existing = db.query(Vehicle).filter(
            Vehicle.vehicle_number == data.vehicle_number
        ).first()

        if existing:
            raise HTTPException(
                status_code=400,
                detail="Vehicle number already exists"
            )

    update_data = data.dict(exclude_unset=True)

    for key, value in update_data.items():
        setattr(vehicle, key, value)

    db.commit()
    db.refresh(vehicle)

    return vehicle


@router.delete(
    "/{vehicle_id}"
)
def delete_vehicle(
    vehicle_id: int,
    current_user=Depends(admin_manager),
    db: Session = Depends(get_db)
):

    vehicle = db.query(Vehicle).filter(
        Vehicle.id == vehicle_id,
        Vehicle.is_active == True
    ).first()

    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    # Soft delete — preserve data integrity for existing trips
    vehicle.is_active = False
    db.commit()

    return {"message": f"Vehicle {vehicle.vehicle_number} deleted successfully"}
