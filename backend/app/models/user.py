from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from datetime import datetime

from app.db.session import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("company_id", "email", name="uq_company_user_email"),
        {"schema": "auth"},
    )

    id = Column(Integer, primary_key=True, index=True)

    # ─── Legacy single-tenant role (auth.roles) ───────────────────────────────
    role_id = Column(
        Integer,
        ForeignKey("auth.roles.id"),
        nullable=True,
    )

    # ─── Multi-tenant fields ──────────────────────────────────────────────────
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    # Per-company role (tenant.user_roles)
    user_role_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.user_roles.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    company = relationship("Company", back_populates="users")

    full_name = Column(String(100), nullable=False)

    email = Column(String(120), nullable=False)

    password_hash = Column(String(255), nullable=False)

    is_active = Column(Boolean, default=True)

    created_at = Column(DateTime, default=datetime.utcnow)