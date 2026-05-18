"""
Trip Expense API — log individual expenses during an active trip.

Expenses can only be added when trip.status == STARTED.
After each add, trip.trip_expense is auto-recomputed from the sum of all expenses.
"""

from fastapi import APIRouter, Depends, HTTPException

from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.trip import Trip, TripStatus
from app.models.trip_expense import TripExpense

from app.schemas.trip_expense_schema import (
    TripExpenseCreate,
    TripExpenseResponse,
    TripExpenseSummary,
)

from app.api.dependencies import require_permission, get_db
from app.core.permissions import Permission
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company

# Phase 3 cleanup (DB-001): get_db() imported from dependencies — local copy removed

router = APIRouter()


def _recompute_trip_expense(trip_id: int, company_id, db: Session) -> float:
    """
    Sum all logged expenses for this trip and persist on the trip row.
    Phase 3 fix: company_id passed explicitly to scope the Trip update.
    """
    total = (
        db.query(func.coalesce(func.sum(TripExpense.amount), 0.0))
        .filter(
            TripExpense.trip_id == trip_id,
            TripExpense.company_id == company_id,
        )
        .scalar()
    )

    total = float(total or 0.0)

    # Scope the update to company_id for defence-in-depth
    db.query(Trip).filter(
        Trip.id == trip_id,
        Trip.company_id == company_id,
    ).update({"trip_expense": total})

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
    current_user=Depends(require_permission(Permission.MANAGE_EXPENSES)),
    db: Session = Depends(get_db)
):
    trip = filter_by_company(
        db.query(Trip), Trip
    ).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if trip.trip_status != TripStatus.STARTED:
        raise HTTPException(
            status_code=409,
            detail=f"Expenses can only be added to STARTED trips (current: {trip.trip_status})"
        )

    expense = TripExpense(
        company_id=current_user.company_id,
        trip_id=trip_id,
        expense_type=data.expense_type,
        amount=data.amount,
        remarks=data.remarks,
    )

    db.add(expense)
    db.flush()

    # Recompute trip.trip_expense total
    _recompute_trip_expense(trip_id, current_user.company_id, db)

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
    current_user=Depends(require_permission(Permission.VIEW_TRIPS)),
    db: Session = Depends(get_db)
):
    trip = filter_by_company(
        db.query(Trip), Trip
    ).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    expenses = (
        filter_by_company(db.query(TripExpense), TripExpense)
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
    current_user=Depends(require_permission(Permission.MANAGE_EXPENSES)),
    db: Session = Depends(get_db)
):
    trip = filter_by_company(
        db.query(Trip), Trip
    ).filter(Trip.id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if trip.trip_status != TripStatus.STARTED:
        raise HTTPException(
            status_code=409,
            detail="Expenses can only be deleted from STARTED trips"
        )

    expense = filter_by_company(
        db.query(TripExpense), TripExpense
    ).filter(
        TripExpense.id == expense_id,
        TripExpense.trip_id == trip_id
    ).first()

    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    db.delete(expense)
    db.flush()

    _recompute_trip_expense(trip_id, current_user.company_id, db)

    db.commit()

    return {"message": f"Expense #{expense_id} deleted and trip total updated"}
