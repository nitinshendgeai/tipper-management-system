"""
DocumentRecord model — Phase 9 enterprise module.

Tracks document metadata for drivers, vehicles, insurance, permits.
No binary file storage — stores metadata + expiry dates only.
Future: add file_path for S3/cloud storage integration.

Schema: operations (company-scoped operational records)
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Date, Boolean
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime

from app.db.session import Base


class DocumentCategory:
    DRIVER     = "DRIVER"      # DL, Aadhaar, PAN, medical fitness
    VEHICLE    = "VEHICLE"     # RC, fitness certificate, pollution
    INSURANCE  = "INSURANCE"   # vehicle insurance policy
    PERMIT     = "PERMIT"      # route permit, national permit, goods carriage
    OTHER      = "OTHER"


class DocumentRecord(Base):

    __tablename__ = "documents"
    __table_args__ = {"schema": "operations"}

    id = Column(Integer, primary_key=True, index=True)

    # ─── Multi-tenant ─────────────────────────────────────────────────────────
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    # ─── Category & identity ──────────────────────────────────────────────────
    category = Column(String(30), nullable=False, default=DocumentCategory.OTHER)
    document_name = Column(String(200), nullable=False)
    document_number = Column(String(100), nullable=True)   # license no, policy no, etc.

    # ─── Entity links (vehicle OR driver — both optional for company-level docs) ─
    vehicle_id = Column(
        Integer,
        ForeignKey("master.vehicles.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    driver_id = Column(
        Integer,
        ForeignKey("master.drivers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # ─── Dates & expiry ───────────────────────────────────────────────────────
    issue_date  = Column(Date, nullable=True)
    expiry_date = Column(Date, nullable=True, index=True)  # indexed for expiry queries

    # ─── Storage placeholder (metadata only for now) ─────────────────────────
    # Future: store S3 key / GCS path / local file path
    file_path = Column(String(500), nullable=True)

    # ─── Notes ────────────────────────────────────────────────────────────────
    notes = Column(String(500), nullable=True)

    # ─── Audit ────────────────────────────────────────────────────────────────
    created_by_user_id = Column(
        Integer,
        ForeignKey("auth.users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=True, onupdate=datetime.utcnow)
