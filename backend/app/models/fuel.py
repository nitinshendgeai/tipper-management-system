"""
FuelEntry model — Phase 9 enterprise module.

Tracks fuel fill-ups per vehicle, optionally linked to a trip.
Supports mileage tracking and fuel cost analytics.

Schema: operations (operational records scoped by company_id)
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Date
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime

from app.db.session import Base


class FuelEntry(Base):

    __tablename__ = "fuel_entries"
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

    # ─── Driver link (optional — who filled the fuel) ─────────────────────────
    driver_id = Column(
        Integer,
        ForeignKey("master.drivers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # ─── Trip link (optional — if fuel filled during a specific trip) ─────────
    trip_id = Column(
        Integer,
        ForeignKey("operations.trips.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # ─── Fuel details ─────────────────────────────────────────────────────────
    fuel_date = Column(Date, nullable=False, default=datetime.utcnow)
    quantity_litres = Column(Float, nullable=False)  # mandatory
    cost_per_litre = Column(Float, nullable=True)
    total_cost = Column(Float, nullable=True)  # auto-computed or manual override

    # ─── Odometer (for mileage / efficiency analytics) ────────────────────────
    odometer_km = Column(Float, nullable=True)

    # ─── Fill-up location ─────────────────────────────────────────────────────
    fuel_station = Column(String(200), nullable=True)

    # ─── Notes ────────────────────────────────────────────────────────────────
    notes = Column(String(500), nullable=True)

    # ─── Audit ────────────────────────────────────────────────────────────────
    created_by_user_id = Column(
        Integer,
        ForeignKey("auth.users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at = Column(DateTime, default=datetime.utcnow)
