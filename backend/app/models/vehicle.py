from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    ForeignKey,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from datetime import datetime

from app.db.session import Base


# ─── Vehicle Status Constants ─────────────────────────────────────────────────

class VehicleStatus:
    AVAILABLE   = "AVAILABLE"
    ASSIGNED    = "ASSIGNED"
    ON_TRIP     = "ON_TRIP"
    MAINTENANCE = "MAINTENANCE"


class Vehicle(Base):

    __tablename__ = "vehicles"
    __table_args__ = {"schema": "master"}

    id = Column(Integer, primary_key=True, index=True)

    # ─── Multi-tenant ─────────────────────────────────────────────────────────
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    company = relationship("Company", back_populates="vehicles")

    vehicle_number = Column(
        String(20),
        unique=True,
        nullable=False
    )

    vehicle_type = Column(
        String(50),
        nullable=False
    )

    capacity_ton = Column(Integer)

    owner_name = Column(String(100))

    mobile_number = Column(String(20))

    rc_number = Column(String(100))

    insurance_expiry = Column(String(20))

    # ─── Operational status ───────────────────────────────────────────────────
    # AVAILABLE | ASSIGNED | ON_TRIP | MAINTENANCE
    status = Column(
        String(20),
        default=VehicleStatus.AVAILABLE,
        nullable=False
    )

    is_active = Column(
        Boolean,
        default=True
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )
