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


# ─── Driver Status Constants ──────────────────────────────────────────────────

class DriverStatus:
    OFF_DUTY  = "OFF_DUTY"
    AVAILABLE = "AVAILABLE"
    ON_TRIP   = "ON_TRIP"
    BREAK     = "BREAK"


class Driver(Base):

    __tablename__ = "drivers"
    __table_args__ = {"schema": "master"}

    id = Column(Integer, primary_key=True, index=True)

    # ─── Multi-tenant ─────────────────────────────────────────────────────────
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    company = relationship("Company", back_populates="drivers")

    vehicle_id = Column(
        Integer,
        ForeignKey("master.vehicles.id"),
        nullable=True
    )

    full_name = Column(
        String(100),
        nullable=False
    )

    mobile_number = Column(
        String(20),
        nullable=False
    )

    license_number = Column(
        String(100),
        unique=True,
        nullable=False
    )

    license_expiry = Column(String(20))

    aadhaar_number = Column(String(20))

    address = Column(String(255))

    emergency_contact = Column(String(20))

    # ─── Operational status ───────────────────────────────────────────────────
    # OFF_DUTY | AVAILABLE | ON_TRIP | BREAK
    status = Column(
        String(20),
        default=DriverStatus.OFF_DUTY,
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
