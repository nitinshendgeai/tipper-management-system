from pydantic import BaseModel
from typing import Optional


class LoginRequest(BaseModel):
    """
    Login credentials.

    Phase 6 (AUTH-001): added optional company_slug field.
    When provided, login is scoped to that specific company — preventing
    cross-tenant authentication when two companies share a user email.
    If omitted, falls back to email-only lookup (backward-compatible).
    """
    email: str
    password: str
    company_slug: Optional[str] = None     # e.g. "acme-transport" — from company registration


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    must_change_password: bool = False