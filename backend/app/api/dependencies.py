from jose import jwt, JWTError

from fastapi import Depends, HTTPException, status

from fastapi.security import HTTPBearer
from fastapi.security.http import HTTPAuthorizationCredentials

from sqlalchemy.orm import Session

from app.core.config import (
    SECRET_KEY,
    ALGORITHM
)

from app.db.session import SessionLocal
from app.models.user import User

security = HTTPBearer()


def get_db():

    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):

    token = credentials.credentials

    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials"
    )

    try:

        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        email: str = payload.get("sub")

        if email is None:
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    user = db.query(User).filter(
        User.email == email
    ).first()

    if user is None:
        raise credentials_exception

    return user


# ─── Multi-tenant dependency ──────────────────────────────────────────────────


def get_current_tenant_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    """
    Authenticate the request and populate TenantContext for the current
    async task.  Returns the User ORM object.

    Use this dependency on any endpoint that requires tenant isolation.
    """
    from app.core.tenant import TenantContext, extract_tenant_from_token

    token = credentials.credentials
    company_id, email, role_name = extract_tenant_from_token(token)

    # Set context vars for this request
    TenantContext.set_company_id(company_id)
    TenantContext.set_role_name(role_name)

    user = db.query(User).filter(
        User.email == email,
        User.company_id == company_id,
    ).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found for this company",
        )

    TenantContext.set_user_id(user.id)
    return user


# ─── Permission-based dependency factory ─────────────────────────────────────


def require_permission(permission):
    """
    Dependency factory — checks whether the authenticated user's role
    includes the given Permission. Reads role directly from JWT.
    """
    from app.core.permissions import check_permission
    from app.core.tenant import extract_tenant_from_token

    async def _check(
        credentials: HTTPAuthorizationCredentials = Depends(security),
        db: Session = Depends(get_db),
    ) -> User:
        from app.core.tenant import TenantContext

        token = credentials.credentials
        company_id, email, role_name = extract_tenant_from_token(token)

        TenantContext.set_company_id(company_id)
        TenantContext.set_role_name(role_name)

        user = db.query(User).filter(
            User.email == email,
            User.company_id == company_id,
        ).first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found for this company",
            )

        TenantContext.set_user_id(user.id)

        if not check_permission(role_name, permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission denied — '{permission.value}' required",
            )
        return user

    return _check
