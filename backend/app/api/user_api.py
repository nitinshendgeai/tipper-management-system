"""User Management API — Phase 10."""
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from app.api.dependencies import get_db, require_permission
from app.core.permissions import Permission
from app.core.security import hash_password
from app.core.tenant import TenantContext
from app.db.tenant_queries import filter_by_company
from app.models.user import User
from app.models.company import UserRole

logger = logging.getLogger(__name__)
router = APIRouter()

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
    role_name: str

class UpdateUserRequest(BaseModel):
    full_name: Optional[str] = None
    role_name: Optional[str] = None
    is_active: Optional[bool] = None

ALLOWED_ROLES = {"MANAGER", "SUPERVISOR", "DRIVER"}

def _resolve_role(role_name, company_id, db):
    role = db.query(UserRole).filter(UserRole.company_id == company_id, UserRole.role_name == role_name.upper()).first()
    if not role:
        raise HTTPException(status_code=400, detail=f"Role '{role_name}' not found.")
    return role

def _user_to_response(user, db):
    role_name = None
    if user.user_role_id:
        role = db.query(UserRole).filter(UserRole.id == user.user_role_id).first()
        if role:
            role_name = role.role_name
    return UserResponse(id=user.id, full_name=user.full_name, email=user.email, role_name=role_name, is_active=user.is_active)

@router.get("/", response_model=list[UserResponse])
def list_users(db: Session = Depends(get_db), current_user=Depends(require_permission(Permission.MANAGE_USERS))):
    users = filter_by_company(db.query(User), User).order_by(User.full_name).all()
    return [_user_to_response(u, db) for u in users]

@router.post("/", response_model=UserResponse, status_code=201)
def create_user(data: CreateUserRequest, db: Session = Depends(get_db), current_user=Depends(require_permission(Permission.MANAGE_USERS))):
    company_id = TenantContext.get_company_id()
    if data.role_name.upper() not in ALLOWED_ROLES:
        raise HTTPException(status_code=400, detail=f"Invalid role. Allowed: {', '.join(ALLOWED_ROLES)}")
    if db.query(User).filter(User.company_id == company_id, User.email == data.email).first():
        raise HTTPException(status_code=409, detail=f"User with email '{data.email}' already exists.")
    role = _resolve_role(data.role_name, company_id, db)
    user = User(company_id=company_id, full_name=data.full_name.strip(), email=data.email.lower(), password_hash=hash_password(data.password), user_role_id=role.id, is_active=True, must_change_password=True)
    db.add(user)
    db.commit()
    db.refresh(user)
    return _user_to_response(user, db)

@router.get("/{user_id}", response_model=UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db), current_user=Depends(require_permission(Permission.MANAGE_USERS))):
    user = filter_by_company(db.query(User), User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    return _user_to_response(user, db)

@router.patch("/{user_id}", response_model=UserResponse)
def update_user(user_id: int, data: UpdateUserRequest, db: Session = Depends(get_db), current_user=Depends(require_permission(Permission.MANAGE_USERS))):
    company_id = TenantContext.get_company_id()
    user = filter_by_company(db.query(User), User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    if data.is_active is False and user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot deactivate your own account.")
    if data.full_name:
        user.full_name = data.full_name.strip()
    if data.role_name:
        if data.role_name.upper() not in ALLOWED_ROLES:
            raise HTTPException(status_code=400, detail=f"Invalid role.")
        user.user_role_id = _resolve_role(data.role_name, company_id, db).id
    if data.is_active is not None:
        user.is_active = data.is_active
    db.commit()
    db.refresh(user)
    return _user_to_response(user, db)

@router.delete("/{user_id}")
def deactivate_user(user_id: int, db: Session = Depends(get_db), current_user=Depends(require_permission(Permission.MANAGE_USERS))):
    user = filter_by_company(db.query(User), User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot deactivate your own account.")
    user.is_active = False
    db.commit()
    return {"message": f"User '{user.full_name}' deactivated."}
