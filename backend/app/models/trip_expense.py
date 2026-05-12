"""
TripExpense — individual expense entries added during an active trip.

Expense types (open string, validated at API layer):
  Diesel | Toll | Food/Bata | Repair | Puncture | Police | Other
"""

from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    DateTime,
    ForeignKey,
)
from sqlalchemy.dialects.postgresql import UUID

from datetime import datetime

from app.db.session import Base


# ─── Expense Type Constants ───────────────────────────────────────────────────

class ExpenseType:
    DIESEL  = "Diesel"
    TOLL    = "Toll"
    BATA    = "Food/Bata"
    REPAIR  = "Repair"
    PUNCTURE = "Puncture"
    POLICE  = "Police"
    OTHER   = "Other"

    ALL = [DIESEL, TOLL, BATA, REPAIR, PUNCTURE, POLICE, OTHER]


class TripExpense(Base):

    __tablename__ = "trip_expenses"
    __table_args__ = {"schema": "operations"}

    id = Column(Integer, primary_key=True, index=True)

    # ─── Multi-tenant ─────────────────────────────────────────────────────────
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    trip_id = Column(
        Integer,
        ForeignKey("operations.trips.id"),
        nullable=False
    )

    expense_type = Column(
        String(50),
        nullable=False
    )

    amount = Column(
        Float,
        nullable=False
    )

    remarks = Column(String(255), nullable=True)

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )
