from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    Float,
    ForeignKey,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from datetime import datetime

from app.db.session import Base


# ─── Trip Status Constants ────────────────────────────────────────────────────

class TripStatus:
    CREATED   = "CREATED"
    STARTED   = "STARTED"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class Trip(Base):

    __tablename__ = "trips"
    __table_args__ = {"schema": "operations"}

    id = Column(Integer, primary_key=True, index=True)

    # ─── Multi-tenant ─────────────────────────────────────────────────────────
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    company = relationship("Company", back_populates="trips")

    vehicle_id = Column(
        Integer,
        ForeignKey("master.vehicles.id"),
        nullable=False
    )

    driver_id = Column(
        Integer,
        ForeignKey("master.drivers.id"),
        nullable=False
    )

    route_id = Column(
        Integer,
        ForeignKey("master.routes.id"),
        nullable=True       # route is optional; AI fields capture the real data
    )

    # ─── Route details (AI-populated or manual) ───────────────────────────────

    source_location = Column(String(255), nullable=True)

    destination_location = Column(String(255), nullable=True)

    # Google Maps calculated values
    calculated_distance_km   = Column(Float, nullable=True)
    estimated_duration_min   = Column(Integer, nullable=True)
    estimated_diesel         = Column(Float, nullable=True)

    # Supervisor may override distance after AI calculation
    distance_km_override = Column(Float, nullable=True)

    # ─── Status ───────────────────────────────────────────────────────────────
    # CREATED | STARTED | COMPLETED | CANCELLED

    trip_date = Column(DateTime, default=datetime.utcnow)

    trip_status = Column(
        String(20),
        default=TripStatus.CREATED,
        nullable=False
    )

    # ─── Start fields ─────────────────────────────────────────────────────────

    start_time = Column(DateTime, nullable=True)

    start_km = Column(Float, nullable=True)

    # ─── Completion fields ────────────────────────────────────────────────────

    end_time = Column(DateTime, nullable=True)

    end_km = Column(Float, nullable=True)

    diesel_issued = Column(Float, nullable=True)

    diesel_used = Column(Float, nullable=True)

    trip_advance = Column(Float, nullable=True)

    trip_expense = Column(Float, nullable=True)     # sum of all expenses

    toll_expense = Column(Float, nullable=True)

    driver_bata = Column(Float, nullable=True)

    revenue_amount = Column(Float, nullable=True)

    # ─── Cancellation ─────────────────────────────────────────────────────────

    cancelled_at = Column(DateTime, nullable=True)

    cancellation_reason = Column(String(255), nullable=True)

    # ─── General ──────────────────────────────────────────────────────────────

    remarks = Column(String(255), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
