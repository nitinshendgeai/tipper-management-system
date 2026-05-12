"""
Tenant context — extracts and holds per-request company/user/role identity.

Design note: We use a simple module-level approach with contextvars for
async-safe per-request isolation. Each request sets its own context.
"""

from contextvars import ContextVar
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from jose import jwt, JWTError

from app.core.config import SECRET_KEY, ALGORITHM


# ─── Per-request context variables (async-safe) ───────────────────────────────

_company_id_var: ContextVar[Optional[UUID]] = ContextVar(
    "_company_id_var", default=None
)
_user_id_var: ContextVar[Optional[int]] = ContextVar("_user_id_var", default=None)
_role_name_var: ContextVar[Optional[str]] = ContextVar(
    "_role_name_var", default=None
)


class TenantContext:
    """Async-safe per-request tenant context backed by contextvars."""

    @classmethod
    def set_company_id(cls, company_id: UUID) -> None:
        _company_id_var.set(company_id)

    @classmethod
    def get_company_id(cls) -> UUID:
        value = _company_id_var.get()
        if value is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Tenant context not set — authenticate first",
            )
        return value

    @classmethod
    def set_user_id(cls, user_id: int) -> None:
        _user_id_var.set(user_id)

    @classmethod
    def get_user_id(cls) -> Optional[int]:
        return _user_id_var.get()

    @classmethod
    def set_role_name(cls, role_name: str) -> None:
        _role_name_var.set(role_name)

    @classmethod
    def get_role_name(cls) -> Optional[str]:
        return _role_name_var.get()


def extract_tenant_from_token(token: str) -> tuple[UUID, str, str]:
    """
    Decode JWT and return (company_id, user_email, role_name).

    Raises HTTP 401 if the token is invalid or missing required claims.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    company_id_str: Optional[str] = payload.get("company_id")
    email: Optional[str] = payload.get("sub")
    role_name: Optional[str] = payload.get("role_name")

    if not all([company_id_str, email, role_name]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing required tenant claims (company_id, sub, role_name)",
        )

    try:
        company_id = UUID(company_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token contains invalid company_id",
        )

    return company_id, email, role_name
