import logging

from fastapi import (
    APIRouter,
    HTTPException,
    Depends
)

from sqlalchemy import func as sa_func

from app.db.session import SessionLocal
from app.models.user import User
from app.models.company import Company, UserRole

from app.schemas.auth_schema import (
    LoginRequest,
    TokenResponse
)

from app.core.security import (
    verify_password,
    create_access_token
)

from app.api.dependencies import get_current_tenant_user

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/login",
    response_model=TokenResponse
)
def login(data: LoginRequest):
    """
    Authenticate a user and return a JWT access token.

    Phase 6 fix (AUTH-001): when `company_slug` (company name) is supplied in
    the request body, the login is strictly scoped to that company — preventing
    cross-tenant authentication in the event that two companies share a user email.
    If `company_slug` is omitted the endpoint falls back to email-only lookup
    for backward-compatibility with existing Flutter clients that haven't yet
    been updated to send the company name.
    """

    db = SessionLocal()
    try:
        # ── Resolve company scope when company_slug is provided ────────────────
        company_id_filter = None
        if data.company_slug:
            company = db.query(Company).filter(
                sa_func.lower(Company.company_name) == data.company_slug.strip().lower(),
                Company.is_active == True,
            ).first()
            if not company:
                logger.warning(
                    "Login failed — unknown company_slug: %s (email: %s)",
                    data.company_slug, data.email,
                )
                raise HTTPException(
                    status_code=401,
                    detail="Invalid company name, email, or password"
                )
            company_id_filter = company.id
            logger.debug("Login: company resolved — %s (id=%s)", company.company_name, company.id)

        # ── Lookup user — scoped to company when provided ──────────────────────
        user_query = db.query(User).filter(
            User.email == data.email,
            User.is_active == True,
        )
        if company_id_filter is not None:
            user_query = user_query.filter(User.company_id == company_id_filter)

        user = user_query.first()

        if not user:
            logger.warning(
                "Login failed — user not found (email: %s, company_slug: %s)",
                data.email, data.company_slug or "<not provided>",
            )
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        if not verify_password(data.password, user.password_hash):
            logger.warning(
                "Login failed — wrong password (email: %s, company_id: %s)",
                data.email, user.company_id,
            )
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

        logger.info(
            "Login success — email=%s role=%s company_id=%s",
            user.email, role_name, user.company_id,
        )

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
