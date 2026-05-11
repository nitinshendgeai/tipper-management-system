"""
Trip Expense API — log individual expenses during an active trip.

Expenses can only be added when trip.status == STARTED.
After each add, trip.trip_expense is auto-recomputed from the sum of all expenses.
"""

from fastapi import APIRouter, Depends, HTTPException

from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.session import SessionLocal

from app.models.trip import Trip, TripStatus
from app.models.trip_expense import TripExpense

from app.schemas.trip_expense_schema import (
    TripExpenseCreate,
    TripExpenseResponse,
    TripExpenseSummary,
)

from app.api.role_checker import RoleChecker


supervisor = RoleChecker([1, 2, 3])

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _recompute_trip_expense(trip_id: int, db: Session) -> float:
    """Sum all logged expenses for this trip and persist on the trip row."""

    total = (
        db.query(func.coalesce(func.sum(TripExpense.amount), 0.0))
        .filter(TripExpense.trip_id == trip_id)
        .scalar()
    )

    total = float(total or 0.0)

    db.query(Trip).filter(Trip.id == trip_id).update(
        {"trip_expense": total}
    )

    return total


# ─── ADD EXPENSE ──────────────────────────────────────────────────────────────

@router.post(
    "/{trip_id}/expenses",
    response_model=TripExpenseResponse,
    summary="Add an expense to an active trip"
)
def add_expense(
    trip_id: int,
    data: TripExpenseCreate,
    current_user=Depends(supervisor),
    db: Session = Depends(get_db)
):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if trip.trip_status != TripStatus.STARTED:
        raise HTTPException(
            status_code=409,
            detail=f"Expenses can only be added to STARTED trips (current: {trip.trip_status})"
        )

    expense = TripExpense(
        trip_id=trip_id,
        expense_type=data.expense_type,
        amount=data.amount,
        remarks=data.remarks,
    )

    db.add(expense)
    db.flush()

    # Recompute trip.trip_expense total
    _recompute_trip_expense(trip_id, db)

    db.commit()
    db.refresh(expense)

    return expense


# ─── LIST EXPENSES FOR TRIP ────────────────────────────────────────────────────

@router.get(
    "/{trip_id}/expenses",
    response_model=TripExpenseSummary,
    summary="Get all expenses for a trip with summary"
)
def list_expenses(
    trip_id: int,
    db: Session = Depends(get_db)
):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    expenses = (
        db.query(TripExpense)
        .filter(TripExpense.trip_id == trip_id)
        .order_by(TripExpense.created_at)
        .all()
    )

    total = sum(e.amount for e in expenses)

    # Aggregate by type
    by_type: dict[str, float] = {}

    for e in expenses:
        by_type[e.expense_type] = by_type.get(e.expense_type, 0.0) + e.amount

    return TripExpenseSummary(
        trip_id=trip_id,
        total_amount=round(total, 2),
        expenses=[TripExpenseResponse.model_validate(e) for e in expenses],
        by_type={k: round(v, 2) for k, v in by_type.items()},
    )


# ─── DELETE EXPENSE ────────────────────────────────────────────────────────────

@router.delete(
    "/{trip_id}/expenses/{expense_id}",
    summary="Remove an expense entry (trip must still be STARTED)"
)
def delete_expense(
    trip_id: int,
    expense_id: int,
    current_user=Depends(supervisor),
    db: Session = Depends(get_db)
):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if trip.trip_status != TripStatus.STARTED:
        raise HTTPException(
            status_code=409,
            detail="Expenses can only be deleted from STARTED trips"
        )

    expense = db.query(TripExpense).filter(
        TripExpense.id == expense_id,
        TripExpense.trip_id == trip_id
    ).first()

    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    db.delete(expense)
    db.flush()

    _recompute_trip_expense(trip_id, db)

    db.commit()

    return {"message": f"Expense #{expense_id} deleted and trip total updated"}
