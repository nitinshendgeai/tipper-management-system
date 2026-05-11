from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import datetime

from app.models.trip_expense import ExpenseType


# ─── CREATE ───────────────────────────────────────────────────────────────────

class TripExpenseCreate(BaseModel):

    expense_type: str
    amount: float
    remarks: Optional[str] = None

    @field_validator("expense_type")
    @classmethod
    def validate_expense_type(cls, v: str) -> str:
        if v not in ExpenseType.ALL:
            raise ValueError(
                f"Invalid expense type. Must be one of: {ExpenseType.ALL}"
            )
        return v

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Amount must be greater than 0")
        return v


# ─── RESPONSE ─────────────────────────────────────────────────────────────────

class TripExpenseResponse(BaseModel):

    id: int
    trip_id: int
    expense_type: str
    amount: float
    remarks: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ─── SUMMARY ──────────────────────────────────────────────────────────────────

class TripExpenseSummary(BaseModel):
    """Aggregated expense breakdown for a trip."""

    trip_id: int
    total_amount: float
    expenses: list[TripExpenseResponse]
    by_type: dict[str, float]       # { "Diesel": 1200.0, "Toll": 150.0, ... }
