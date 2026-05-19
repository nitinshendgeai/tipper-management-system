"""
Driver Attendance model — operations.attendance

Tracks daily driver punch-in / punch-out for shift management.

Design:
  - One record per driver per shift_date.
  - punch_in is set when driver marks themselves PRESENT.
  - punch_out is set when driver ends the shift or SUPERVISOR releases them.
  - is_active = True means the driver is currently on duty (punched in, not out).
  - status: PRESENT | ABSENT
  - company_id links to tenant.companies (multi-tenant).
"""

from datetime import datetime, date as _date

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID

from app.db.session import Base


class AttendanceStatus:
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"


class DriverAttendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (
        # Prevent duplicate punch-in for the same driver on the same date
        UniqueConstraint("driver_id", "shift_date", "company_id", name="uq_driver_attendance_date"),
        {"schema": "operations"},
    )

    id = Column(Integer, primary_key=True, index=True)

    # Tenant isolation
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    # Driver reference
    driver_id = Column(
        Integer,
        ForeignKey("master.drivers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Shift date (local date — not UTC datetime)
    shift_date = Column(Date, nullable=False, default=_date.today, index=True)

    # Punch timestamps (UTC)
    punch_in = Column(DateTime, nullable=True)
    punch_out = Column(DateTime, nullable=True)

    # PRESENT | ABSENT
    status = Column(String(20), nullable=False, default=AttendanceStatus.PRESENT)

    # True while driver is actively on duty (punched in, not yet punched out)
    is_active = Column(Boolean, nullable=False, default=True)

    # Audit
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
