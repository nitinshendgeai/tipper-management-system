"""
DriverVehicleAssignment — maps a driver to a vehicle for a shift.

Rules enforced at the API layer:
  • A vehicle can have at most ONE active assignment (is_active=True).
  • A driver can have at most ONE active assignment.

When an assignment is created:
  • vehicle.status → ASSIGNED
  • driver.status  → AVAILABLE   (available, on shift, not yet on a trip)

When an assignment is released (is_active → False):
  • vehicle.status → AVAILABLE
  • driver.status  → OFF_DUTY
"""

from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    Date,
    ForeignKey
)

from datetime import datetime, date

from app.db.session import Base


class DriverVehicleAssignment(Base):

    __tablename__ = "driver_vehicle_assignments"
    __table_args__ = {"schema": "master"}

    id = Column(Integer, primary_key=True, index=True)

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

    # Who created this assignment (user.id)
    assigned_by = Column(
        Integer,
        ForeignKey("master.users.id"),
        nullable=True
    )

    assigned_at = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False
    )

    # Shift date (defaults to today)
    shift_date = Column(
        Date,
        default=date.today,
        nullable=False
    )

    released_at = Column(DateTime, nullable=True)

    remarks = Column(String(255), nullable=True)

    # False once the shift ends
    is_active = Column(Boolean, default=True, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow)
