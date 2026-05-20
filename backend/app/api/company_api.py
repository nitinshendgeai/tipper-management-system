"""
Company Registration & Management API.

POST /companies/register  — public endpoint to onboard a new company.
GET  /companies/{id}      — retrieve company details with live stats.

On registration the system automatically creates:
  • Company record
  • CompanySettings (basic tier, 50 users, 100 vehicles)
  • Default UserRole rows (SUPER_ADMIN, MANAGER, SUPERVISOR, DRIVER)
  • An admin user  admin@<slugified-company-name>.com / admin1234
"""

import logging
import secrets
import uuid

from fastapi import APIRouter, HTTPException, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from app.db.session import SessionLocal
from app.models.company import Company, CompanySettings, UserRole
from app.models.user import User
from app.models.role import Role
from app.models.vehicle import Vehicle
from app.schemas.company_schema import (
    CompanyRegisterRequest,
    CompanyResponse,
    CompanyDetailResponse,
)
from app.core.security import hash_password
from app.db.seed import create_default_roles

router = APIRouter()


# ─── Helpers ──────────────────────────────────────────────────────────────────


def _company_slug(name: str) -> str:
    """Convert company name to a safe email-local-part slug."""
    return name.lower().replace(" ", "").replace(".", "").replace(",", "")


# ─── Register Company ─────────────────────────────────────────────────────────


@router.post(
    "/register",
    response_model=CompanyResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new company (public endpoint)",
)
def register_company(data: CompanyRegisterRequest):
    """
    Onboard a new tipper transport company onto the SaaS platform.

    Creates the company, default roles, settings, and an initial SUPER_ADMIN
    user whose credentials are:
      - email:    admin@<company-slug>.com
      - password: admin1234
    """
    db: Session = SessionLocal()
    try:
        # ── Duplicate check ────────────────────────────────────────────────────
        existing = (
            db.query(Company)
            .filter(
                (Company.company_name == data.company_name)
                | (Company.email == data.email)
            )
            .first()
        )

        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Company name or email is already registered",
            )

        # ── Create company ─────────────────────────────────────────────────────
        company = Company(
            company_name=data.company_name,
            owner_name=data.owner_name,
            mobile_number=data.mobile_number,
            email=data.email,
            gst_number=data.gst_number,
            address=data.address,
            is_active=True,
        )
        db.add(company)
        db.flush()  # populate company.id before FK references

        # ── Company settings ───────────────────────────────────────────────────
        settings = CompanySettings(
            company_id=company.id,
            max_users=50,
            max_vehicles=100,
            subscription_tier="basic",
        )
        db.add(settings)

        # ── Default roles ──────────────────────────────────────────────────────
        create_default_roles(db, company.id)

        # ── Admin user ─────────────────────────────────────────────────────────
        slug = _company_slug(data.company_name)
        admin_email = f"admin@{slug}.com"

        # Resolve SUPER_ADMIN role id (just flushed above)
        super_admin_role = (
            db.query(UserRole)
            .filter(
                UserRole.company_id == company.id,
                UserRole.role_name == "SUPER_ADMIN",
            )
            .first()
        )

        # Phase 2 fix (AUTH-006): resolve legacy Admin role by name, not hardcoded id=1
        legacy_admin_role = (
            db.query(Role).filter(Role.name == "Admin").first()
        )

        # Phase 11 (AUTH-004): use caller-supplied password or generate a
        # cryptographically secure random one. Flag for forced change on first login.
        admin_password = (
            data.initial_password.strip()
            if data.initial_password
            else secrets.token_urlsafe(12)
        )

        admin_user = User(
            email=admin_email,
            password_hash=hash_password(admin_password),
            full_name=f"Admin — {data.company_name}",
            company_id=company.id,
            user_role_id=super_admin_role.id if super_admin_role else None,
            role_id=legacy_admin_role.id if legacy_admin_role else None,
            must_change_password=True,
        )
        db.add(admin_user)

        db.commit()
        db.refresh(company)

        # Return admin credentials in response — shown ONCE, never stored
        response = CompanyResponse.model_validate(company)
        response.admin_email    = admin_email
        response.admin_password = admin_password
        return response

    except HTTPException:
        db.rollback()
        raise
    except Exception as exc:
        db.rollback()
        # Phase 7 fix (TENANT-004): log internally, never leak raw exception to client
        logger.error("Company registration failed: %s", exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Company registration failed due to a server error. Please try again.",
        )
    finally:
        db.close()


# ─── Get Company ──────────────────────────────────────────────────────────────


@router.get(
    "/{company_id}",
    response_model=CompanyDetailResponse,
    summary="Get company details with live stats",
)
def get_company(company_id: str):
    """Return company profile plus current user and vehicle counts."""
    db: Session = SessionLocal()
    try:
        try:
            cid = uuid.UUID(company_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid company_id format")

        company = db.query(Company).filter(Company.id == cid).first()

        if not company:
            raise HTTPException(status_code=404, detail="Company not found")

        user_count = (
            db.query(User).filter(User.company_id == company.id).count()
        )
        vehicle_count = (
            db.query(Vehicle).filter(Vehicle.company_id == company.id).count()
        )

        base = CompanyResponse.model_validate(company)

        return CompanyDetailResponse(
            **base.model_dump(),
            max_users=company.settings.max_users if company.settings else 50,
            max_vehicles=company.settings.max_vehicles if company.settings else 100,
            subscription_tier=(
                company.settings.subscription_tier if company.settings else "basic"
            ),
            user_count=user_count,
            vehicle_count=vehicle_count,
        )
    except HTTPException:
        raise
    finally:
        db.close()
