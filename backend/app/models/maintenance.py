"""
VehicleMaintenance model — Phase 9 enterprise module.

Tracks scheduled and completed maintenance events per vehicle.
Supports routine service, repairs, tyre changes, inspections.

Schema: operations (operational records scoped by company_id)
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Date
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime

from app.db.session import Base


class MaintenanceStatus:
    SCHEDULED   = "SCHEDULED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED   = "COMPLETED"
    CANCELLED   = "CANCELLED"


class MaintenanceType:
    ROUTINE    = "ROUTINE"       # Scheduled oil change, filter replacement, etc.
    REPAIR     = "REPAIR"        # Unplanned breakdown repair
    TYRE       = "TYRE"          # Tyre replacement / rotation
    INSPECTION = "INSPECTION"    # Government fitness, pollution check
    OTHER      = "OTHER"


class VehicleMaintenance(Base):

    __tablename__ = "maintenance_logs"
    __table_args__ = {"schema": "operations"}

    id = Column(Integer, primary_key=True, index=True)

    # ─── Multi-tenant ─────────────────────────────────────────────────────────
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    # ─── Vehicle link ─────────────────────────────────────────────────────────
    vehicle_id = Column(
        Integer,
        ForeignKey("master.vehicles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ─── Maintenance details ──────────────────────────────────────────────────
    maintenance_type = Column(String(30), nullable=False, default=MaintenanceType.ROUTINE)
    # SCHEDULED | IN_PROGRESS | COMPLETED | CANCELLED
    status = Column(String(20), nullable=False, default=MaintenanceStatus.SCHEDULED)

    description = Column(String(500), nullable=False)

    # ─── Scheduling ───────────────────────────────────────────────────────────
    scheduled_date = Column(Date, nullable=True)
    completed_date = Column(Date, nullable=True)

    # ─── Cost & odometer ─────────────────────────────────────────────────────
    cost = Column(Float, nullable=True)
    odometer_km = Column(Float, nullable=True)  # km at time of maintenance

    # ─── Vendor ───────────────────────────────────────────────────────────────
    vendor_name = Column(String(200), nullable=True)

    # ─── Audit ────────────────────────────────────────────────────────────────
    notes = Column(String(500), nullable=True)
    created_by_user_id = Column(
        Integer,
        ForeignKey("auth.users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=True, onupdate=datetime.utcnow)
