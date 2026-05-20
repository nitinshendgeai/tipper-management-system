"""
Document Management API — Phase 9.

Endpoints:
  POST   /documents/                   Create document record (metadata only)
  GET    /documents/                   List documents (filters: category, vehicle, driver)
  GET    /documents/expiring           Documents expiring within N days
  GET    /documents/{id}               Get single document
  PUT    /documents/{id}               Update document
  DELETE /documents/{id}               Delete document

All endpoints are tenant-isolated via filter_by_company().
Expiry status is computed server-side (is_expired, days_to_expiry).
"""

import logging
from datetime import datetime, date
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.models.document import DocumentRecord, DocumentCategory
from app.models.vehicle import Vehicle
from app.models.driver import Driver
from app.schemas.document_schema import (
    DocumentCreate,
    DocumentUpdate,
    DocumentResponse,
)
from app.api.dependencies import require_permission, get_current_tenant_user, get_db
from app.core.permissions import Permission
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company

logger = logging.getLogger(__name__)

router = APIRouter()


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _get_doc_or_404(doc_id: int, db: Session) -> DocumentRecord:
    doc = (
        filter_by_company(db.query(DocumentRecord), DocumentRecord)
        .filter(DocumentRecord.id == doc_id)
        .first()
    )
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found.")
    return doc


def _compute_expiry(expiry_date: Optional[date]):
    """Return (is_expired, days_to_expiry) based on today."""
    if expiry_date is None:
        return None, None
    today = date.today()
    delta = (expiry_date - today).days
    return delta < 0, delta


def _enrich(doc: DocumentRecord, db: Session) -> DocumentResponse:
    vehicle = None
    if doc.vehicle_id:
        vehicle = (
            filter_by_company(db.query(Vehicle), Vehicle)
            .filter(Vehicle.id == doc.vehicle_id)
            .first()
        )
    driver = None
    if doc.driver_id:
        driver = (
            filter_by_company(db.query(Driver), Driver)
            .filter(Driver.id == doc.driver_id)
            .first()
        )

    is_expired, days_to_expiry = _compute_expiry(doc.expiry_date)

    return DocumentResponse(
        id=doc.id,
        company_id=str(doc.company_id) if doc.company_id else None,
        category=doc.category,
        document_name=doc.document_name,
        document_number=doc.document_number,
        vehicle_id=doc.vehicle_id,
        vehicle_number=vehicle.vehicle_number if vehicle else None,
        driver_id=doc.driver_id,
        driver_name=driver.full_name if driver else None,
        issue_date=doc.issue_date,
        expiry_date=doc.expiry_date,
        is_expired=is_expired,
        days_to_expiry=days_to_expiry,
        file_path=doc.file_path,
        notes=doc.notes,
        created_by_user_id=doc.created_by_user_id,
        created_at=doc.created_at,
        updated_at=doc.updated_at,
    )


def _bulk_enrich(docs: List[DocumentRecord], db: Session) -> List[DocumentResponse]:
    """Bulk enrichment with a single vehicle + driver query each."""
    vehicle_ids = list({d.vehicle_id for d in docs if d.vehicle_id})
    driver_ids  = list({d.driver_id  for d in docs if d.driver_id})

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

    result = []
    for doc in docs:
        is_expired, days_to_expiry = _compute_expiry(doc.expiry_date)
        result.append(DocumentResponse(
            id=doc.id,
            company_id=str(doc.company_id) if doc.company_id else None,
            category=doc.category,
            document_name=doc.document_name,
            document_number=doc.document_number,
            vehicle_id=doc.vehicle_id,
            vehicle_number=vmap.get(doc.vehicle_id) if doc.vehicle_id else None,
            driver_id=doc.driver_id,
            driver_name=dmap.get(doc.driver_id) if doc.driver_id else None,
            issue_date=doc.issue_date,
            expiry_date=doc.expiry_date,
            is_expired=is_expired,
            days_to_expiry=days_to_expiry,
            file_path=doc.file_path,
            notes=doc.notes,
            created_by_user_id=doc.created_by_user_id,
            created_at=doc.created_at,
            updated_at=doc.updated_at,
        ))
    return result


# ─── Create ───────────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create document record",
)
def create_document(
    data: DocumentCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_permission(Permission.MANAGE_DOCUMENTS)),
):
    company_id = TenantContext.get_company_id()

    # Validate entity links if provided
    if data.vehicle_id:
        v = filter_by_company(db.query(Vehicle), Vehicle).filter(Vehicle.id == data.vehicle_id).first()
        if not v:
            raise HTTPException(status_code=404, detail="Vehicle not found.")
    if data.driver_id:
        d = filter_by_company(db.query(Driver), Driver).filter(Driver.id == data.driver_id).first()
        if not d:
            raise HTTPException(status_code=404, detail="Driver not found.")

    doc = DocumentRecord(
        company_id=company_id,
        category=data.category.upper(),
        document_name=data.document_name,
        document_number=data.document_number,
        vehicle_id=data.vehicle_id,
        driver_id=data.driver_id,
        issue_date=data.issue_date,
        expiry_date=data.expiry_date,
        file_path=data.file_path,
        notes=data.notes,
        created_by_user_id=current_user.id,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)

    logger.info(
        "[documents] Created id=%d category=%s name=%s company=%s",
        doc.id, doc.category, doc.document_name, company_id,
    )
    return _enrich(doc, db)


# ─── List ─────────────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=List[DocumentResponse],
    summary="List documents",
)
def list_documents(
    category: Optional[str] = Query(None),
    vehicle_id: Optional[int] = Query(None),
    driver_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_DOCUMENTS)),
):
    q = filter_by_company(db.query(DocumentRecord), DocumentRecord)

    if category:
        q = q.filter(DocumentRecord.category == category.upper())
    if vehicle_id:
        q = q.filter(DocumentRecord.vehicle_id == vehicle_id)
    if driver_id:
        q = q.filter(DocumentRecord.driver_id == driver_id)

    docs = q.order_by(DocumentRecord.expiry_date.asc().nullslast(), DocumentRecord.created_at.desc()).all()
    return _bulk_enrich(docs, db)


# ─── Expiring documents ───────────────────────────────────────────────────────

@router.get(
    "/expiring",
    response_model=List[DocumentResponse],
    summary="Documents expiring within N days (default 30)",
)
def expiring_documents(
    days: int = Query(default=30, ge=1, le=365),
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_DOCUMENTS)),
):
    from sqlalchemy import and_
    today = date.today()
    cutoff = date.fromordinal(today.toordinal() + days)

    docs = (
        filter_by_company(db.query(DocumentRecord), DocumentRecord)
        .filter(
            DocumentRecord.expiry_date != None,
            DocumentRecord.expiry_date <= cutoff,
        )
        .order_by(DocumentRecord.expiry_date.asc())
        .all()
    )
    return _bulk_enrich(docs, db)


# ─── Get single ───────────────────────────────────────────────────────────────

@router.get(
    "/{doc_id}",
    response_model=DocumentResponse,
    summary="Get document record",
)
def get_document(
    doc_id: int,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.VIEW_DOCUMENTS)),
):
    return _enrich(_get_doc_or_404(doc_id, db), db)


# ─── Update ───────────────────────────────────────────────────────────────────

@router.put(
    "/{doc_id}",
    response_model=DocumentResponse,
    summary="Update document record",
)
def update_document(
    doc_id: int,
    data: DocumentUpdate,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.MANAGE_DOCUMENTS)),
):
    doc = _get_doc_or_404(doc_id, db)
    update_fields = data.model_dump(exclude_unset=True)

    if "category" in update_fields and update_fields["category"]:
        update_fields["category"] = update_fields["category"].upper()

    for field, value in update_fields.items():
        setattr(doc, field, value)

    doc.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(doc)
    return _enrich(doc, db)


# ─── Delete ───────────────────────────────────────────────────────────────────

@router.delete(
    "/{doc_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete document record",
)
def delete_document(
    doc_id: int,
    db: Session = Depends(get_db),
    _=Depends(require_permission(Permission.MANAGE_DOCUMENTS)),
):
    doc = _get_doc_or_404(doc_id, db)
    db.delete(doc)
    db.commit()
    logger.info("[documents] Deleted id=%d", doc_id)
