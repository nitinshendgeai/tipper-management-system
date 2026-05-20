"""
User Management API — Phase 10.

Allows MANAGER / SUPER_ADMIN to manage company users.
All endpoints are company-scoped via TenantContext.

Endpoints:
  GET    /users/              — list all users in the company
  POST   /users/              — create a new user
  GET    /users/{user_id}     — get a single user
  PATCH  /users/{user_id}     — update name / role
  DELETE /users/{user_id}     — deactivate user (soft delete)

Permission required: MANAGE_USERS
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app.api.dependencies import get_db, require_permission, get_current_tenant_user
from app.core.permissions import Permission
from app.core.security import hash_password
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company
from app.models.user import User
from app.models.company import UserRole

logger = logging.getLogger(__name__)
router = APIRouter()


# ─── Schemas ──────────────────────────────────────────────────────────────────

class UserResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role_name: Optional[str] = None
    is_active: bool

    class Config:
        from_attributes = True


class CreateUserRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    role_name: str   # MANAGER | SUPERVISOR | DRIVER


class UpdateUserRequest(BaseModel):
    full_name: Optional[str] = None
    role_name: Optional[str] = None
    is_active: Optional[bool] = None


# ─── Helpers ──────────────────────────────────────────────────────────────────

ALLOWED_ROLES = {"MANAGER", "SUPERVISOR", "DRIVER"}


def _resolve_role(role_name: str, company_id, db: Session) -> UserRole:
    """Fetch the UserRole for this company by role_name."""
    role = db.query(UserRole).filter(
        UserRole.company_id == company_id,
        UserRole.role_name == role_name.upper(),
    ).first()
    if not role:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Role '{role_name}' not found for this company.",
        )
    return role


def _user_to_response(user: User, db: Session) -> UserResponse:
    """Build a UserResponse from a User ORM object."""
    role_name = None
    if user.user_role_id:
        role = db.query(UserRole).filter(UserRole.id == user.user_role_id).first()
        if role:
            role_name = role.role_name
    return UserResponse(
        id=user.id,
        full_name=user.full_name,
        email=user.email,
        role_name=role_name,
        is_active=user.is_active,
    )


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/", response_model=list[UserResponse])
def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(Permission.MANAGE_USERS)),
):
    """List all users in the company (active and inactive)."""
    users = (
        filter_by_company(db.query(User), User)
        .order_by(User.full_name)
        .all()
    )
    return [_user_to_response(u, db) for u in users]


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    data: CreateUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(Permission.MANAGE_USERS)),
):
    """
    Create a new user in the company.
    Role must be one of: MANAGER, SUPERVISOR, DRIVER.
    SUPER_ADMIN cannot be created via this endpoint.
    """
    company_id = TenantContext.get_company_id()

    if data.role_name.upper() not in ALLOWED_ROLES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role. Allowed: {', '.join(ALLOWED_ROLES)}",
        )

    # Check for duplicate email within this company
    existing = db.query(User).filter(
        User.company_id == company_id,
        User.email == data.email,
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"A user with email '{data.email}' already exists in this company.",
        )

    role = _resolve_role(data.role_name, company_id, db)

    new_user = User(
        company_id=company_id,
        full_name=data.full_name.strip(),
        email=data.email.lower().strip(),
        password_hash=hash_password(data.password),
        user_role_id=role.id,
        is_active=True,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    logger.info(
        "User created — id=%s email=%s role=%s company_id=%s created_by=%s",
        new_user.id, new_user.email, data.role_name, company_id, current_user.id,
    )
    return _user_to_response(new_user, db)


@router.get("/{user_id}", response_model=UserResponse)
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(Permission.MANAGE_USERS)),
):
    """Get a single user by ID (must belong to the same company)."""
    user = (
        filter_by_company(db.query(User), User)
        .filter(User.id == user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    return _user_to_response(user, db)


@router.patch("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: int,
    data: UpdateUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(Permission.MANAGE_USERS)),
):
    """Update a user's name, role, or active status."""
    company_id = TenantContext.get_company_id()

    user = (
        filter_by_company(db.query(User), User)
        .filter(User.id == user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    # Prevent self-deactivation
    if data.is_active is False and user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot deactivate your own account.",
        )

    if data.full_name is not None:
        user.full_name = data.full_name.strip()

    if data.role_name is not None:
        if data.role_name.upper() not in ALLOWED_ROLES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid role. Allowed: {', '.join(ALLOWED_ROLES)}",
            )
        role = _resolve_role(data.role_name, company_id, db)
        user.user_role_id = role.id

    if data.is_active is not None:
        user.is_active = data.is_active

    db.commit()
    db.refresh(user)

    logger.info(
        "User updated — id=%s company_id=%s updated_by=%s",
        user.id, company_id, current_user.id,
    )
    return _user_to_response(user, db)


@router.delete("/{user_id}", status_code=status.HTTP_200_OK)
def deactivate_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(Permission.MANAGE_USERS)),
):
    """Soft-delete (deactivate) a user. They cannot log in but data is preserved."""
    user = (
        filter_by_company(db.query(User), User)
        .filter(User.id == user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    if user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot deactivate your own account.",
        )

    user.is_active = False
    db.commit()

    logger.info(
        "User deactivated — id=%s company_id=%s deactivated_by=%s",
        user.id, TenantContext.get_company_id(), current_user.id,
    )
    return {"message": f"User '{user.full_name}' has been deactivated."}
