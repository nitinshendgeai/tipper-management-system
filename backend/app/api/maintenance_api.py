"""
Maintenance Management API — Phase 9.

Endpoints:
  POST   /maintenance/                 Create maintenance log
  GET    /maintenance/                 List logs (filters: vehicle_id, status, type)
  GET    /maintenance/{id}             Get single log
  PUT    /maintenance/{id}             Update log
  DELETE /maintenance/{id}             Delete log
  GET    /maintenance/vehicle/{vid}    All logs for a vehicle

All endpoints are tenant-isolated via filter_by_company().
"""

import logging
from datetime import datetime, date
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.models.maintenance import VehicleMaintenance, MaintenanceStatus
from app.models.vehicle import Vehicle
from app.schemas.maintenance_schema import (
    MaintenanceCreate,
    MaintenanceUpdate,
    MaintenanceResponse,
    MaintenanceSummary,
)
from app.api.dependencies import require_permission, get_current_tenant_user, get_db
from app.core.permissions import Permission
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company

logger = logging.getLogger(__name__)

router = APIRouter()


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _get_maintenance_or_404(maintenance_id: int, db: Session) -> VehicleMaintenance:
    log = (
        filter_by_company(db.query(VehicleMaintenance), VehicleMaintenance)
        .filter(VehicleMaintenance.id == maintenance_id)
        .first()
    )
    if not log:
        raise HTTPException(status_code=404, detail="Maintenance log not found.")
    return log


def _enrich(log: VehicleMaintenance, db: Session) -> MaintenanceResponse:
    vehicle = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.id == log.vehicle_id)
        .first()
    )
    return MaintenanceResponse(
        id=log.id,
        company_id=str(log.company_id) if log.company_id else None,
        vehicle_id=log.vehicle_id,
        vehicle_number=vehicle.vehicle_number if vehicle else None,
        maintenance_type=log.maintenance_type,
        status=log.status,
        description=log.description,
        scheduled_date=log.scheduled_date,
        completed_date=log.completed_date,
        cost=log.cost,
        odometer_km=log.odometer_km,
        vendor_name=log.vendor_name,
        notes=log.notes,
        created_by_user_id=log.created_by_user_id,
        created_at=log.created_at,
        updated_at=log.updated_at,
    )


# ─── Create ───────────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=MaintenanceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create maintenance log",
)
def create_maintenance(
    data: MaintenanceCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_permission(Permission.MANAGE_MAINTENANCE)),
):
    company_id = TenantContext.get_company_id()

    # Validate vehicle belongs to this company
    vehicle = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.id == data.vehicle_id, Vehicle.is_active == True)
        .first()
    )
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found.")

    log = VehicleMaintenance(
        company_id=company_id,
        vehicle_id=data.vehicle_id,
        maintenance_type=data.maintenance_type,
        status=MaintenanceStatus.SCHEDULED,
        description=data.description,
        scheduled_date=data.scheduled_date,
        cost=data.cost,
        odometer_km=data.odometer_km,
        vendor_name=data.vendor_name,
        notes=data.notes,
        created_by_user_id=current_user.id,
    )
    db.add(log)
    db.commit()
    db.refresh(log)

    logger.info(
        "[maintenance] Created log id=%d vehicle=%s type=%s company=%s",
        log.id, vehicle.vehicle_number, log.maintenance_type, company_id,
    )
    return _enrich(log, db)


# ─── List ─────────────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=List[MaintenanceSummary],
    summary="List maintenance logs",
)
def list_maintenance(
    vehicle_id: Optional[int] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    maintenance_type: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_MAINTENANCE)),
):
    q = filter_by_company(db.query(VehicleMaintenance), VehicleMaintenance)

    if vehicle_id:
        q = q.filter(VehicleMaintenance.vehicle_id == vehicle_id)
    if status_filter:
        q = q.filter(VehicleMaintenance.status == status_filter.upper())
    if maintenance_type:
        q = q.filter(VehicleMaintenance.maintenance_type == maintenance_type.upper())

    logs = q.order_by(VehicleMaintenance.created_at.desc()).all()

    # Enrich vehicle numbers in one bulk query
    vehicle_ids = list({log.vehicle_id for log in logs})
    vehicles = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.id.in_(vehicle_ids))
        .all()
    ) if vehicle_ids else []
    vehicle_map = {v.id: v.vehicle_number for v in vehicles}

    return [
        MaintenanceSummary(
            id=log.id,
            vehicle_id=log.vehicle_id,
            vehicle_number=vehicle_map.get(log.vehicle_id),
            maintenance_type=log.maintenance_type,
            status=log.status,
            description=log.description,
            scheduled_date=log.scheduled_date,
            completed_date=log.completed_date,
            cost=log.cost,
            vendor_name=log.vendor_name,
            created_at=log.created_at,
        )
        for log in logs
    ]


# ─── Get single ───────────────────────────────────────────────────────────────

@router.get(
    "/{maintenance_id}",
    response_model=MaintenanceResponse,
    summary="Get maintenance log",
)
def get_maintenance(
    maintenance_id: int,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_MAINTENANCE)),
):
    return _enrich(_get_maintenance_or_404(maintenance_id, db), db)


# ─── Update ───────────────────────────────────────────────────────────────────

@router.put(
    "/{maintenance_id}",
    response_model=MaintenanceResponse,
    summary="Update maintenance log",
)
def update_maintenance(
    maintenance_id: int,
    data: MaintenanceUpdate,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.MANAGE_MAINTENANCE)),
):
    log = _get_maintenance_or_404(maintenance_id, db)

    update_fields = data.model_dump(exclude_unset=True)
    for field, value in update_fields.items():
        setattr(log, field, value)

    log.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(log)

    logger.info("[maintenance] Updated log id=%d status=%s", log.id, log.status)
    return _enrich(log, db)


# ─── Delete ───────────────────────────────────────────────────────────────────

@router.delete(
    "/{maintenance_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete maintenance log",
)
def delete_maintenance(
    maintenance_id: int,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.MANAGE_MAINTENANCE)),
):
    log = _get_maintenance_or_404(maintenance_id, db)
    db.delete(log)
    db.commit()
    logger.info("[maintenance] Deleted log id=%d", maintenance_id)


# ─── By vehicle ───────────────────────────────────────────────────────────────

@router.get(
    "/vehicle/{vehicle_id}",
    response_model=List[MaintenanceSummary],
    summary="Get maintenance logs for a specific vehicle",
)
def list_by_vehicle(
    vehicle_id: int,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_MAINTENANCE)),
):
    # Validate vehicle belongs to this tenant
    vehicle = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(Vehicle.id == vehicle_id)
        .first()
    )
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found.")

    logs = (
        filter_by_company(db.query(VehicleMaintenance), VehicleMaintenance)
        .filter(VehicleMaintenance.vehicle_id == vehicle_id)
        .order_by(VehicleMaintenance.created_at.desc())
        .all()
    )

    return [
        MaintenanceSummary(
            id=log.id,
            vehicle_id=log.vehicle_id,
            vehicle_number=vehicle.vehicle_number,
            maintenance_type=log.maintenance_type,
            status=log.status,
            description=log.description,
            scheduled_date=log.scheduled_date,
            completed_date=log.completed_date,
            cost=log.cost,
            vendor_name=log.vendor_name,
            created_at=log.created_at,
        )
        for log in logs
    ]
