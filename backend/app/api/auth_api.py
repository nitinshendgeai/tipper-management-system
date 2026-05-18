from fastapi import (
    APIRouter,
    HTTPException,
    Depends
)

from app.db.session import SessionLocal
from app.models.user import User
from app.models.company import UserRole

from app.schemas.auth_schema import (
    LoginRequest,
    TokenResponse
)

from app.core.security import (
    verify_password,
    create_access_token
)

from app.api.dependencies import get_current_tenant_user

router = APIRouter()


@router.post(
    "/login",
    response_model=TokenResponse
)
def login(data: LoginRequest):
    """
    Authenticate a user and return a JWT access token.

    Phase 2 note: Login currently matches by email only (no company_id filter).
    This is a known limitation (AUTH-001) — safe only when email addresses are
    globally unique across all tenants. Full tenant-aware login (with company slug)
    is planned for Phase 3.
    """

    db = SessionLocal()
    try:
        user = db.query(User).filter(
            User.email == data.email,
            User.is_active == True,
        ).first()

        if not user:
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        if not verify_password(
            data.password,
            user.password_hash
        ):
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        # ── Resolve role name for tenant-aware token ───────────────────────────
        role_name: str = "SUPER_ADMIN"  # safe default fallback

        if user.user_role_id:
            user_role = db.query(UserRole).filter(
                UserRole.id == user.user_role_id
            ).first()
            if user_role:
                role_name = user_role.role_name

        # ── Build JWT with tenant claims ───────────────────────────────────────
        # Phase 3: added user_id so frontend can identify the user without
        # an extra /auth/me round-trip and for audit trail purposes.
        token_data: dict = {
            "sub": user.email,
            "user_id": user.id,
            "role_id": user.role_id,
            "role_name": role_name,
        }

        if user.company_id:
            token_data["company_id"] = str(user.company_id)

        access_token = create_access_token(data=token_data)

        return {
            "access_token": access_token,
            "token_type": "bearer"
        }
    finally:
        db.close()


@router.get("/me")
def current_user(
    current_user: User = Depends(get_current_tenant_user)
):
    """
    Return the authenticated user's profile.

    Phase 2 fix (AUTH-002): switched from legacy get_current_user (email-only
    lookup) to get_current_tenant_user (email + company_id lookup) for proper
    tenant isolation.
    """

    return {
        "id": current_user.id,
        "full_name": current_user.full_name,
        "email": current_user.email,
        "role_id": current_user.role_id,
        "company_id": str(current_user.company_id) if current_user.company_id else None,
        "user_role_id": str(current_user.user_role_id) if current_user.user_role_id else None,
    }
