"""
Company — top-level tenant entity.

Each company is an independent tipper transport operator.
All master and operational data is scoped to a company via company_id FK.
"""

from sqlalchemy import (
    Column,
    String,
    Boolean,
    DateTime,
    Text,
    Integer,
    JSON,
    ForeignKey,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.db.session import Base


class Company(Base):
    __tablename__ = "companies"
    __table_args__ = {"schema": "tenant"}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    company_name = Column(String(255), unique=True, nullable=False, index=True)
    owner_name = Column(String(255), nullable=False)
    mobile_number = Column(String(20), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    gst_number = Column(String(20), nullable=True)
    address = Column(Text, nullable=True)
    logo_url = Column(String(500), nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    users = relationship(
        "User", back_populates="company", cascade="all, delete-orphan"
    )
    vehicles = relationship(
        "Vehicle", back_populates="company", cascade="all, delete-orphan"
    )
    drivers = relationship(
        "Driver", back_populates="company", cascade="all, delete-orphan"
    )
    routes = relationship(
        "Route", back_populates="company", cascade="all, delete-orphan"
    )
    trips = relationship(
        "Trip", back_populates="company", cascade="all, delete-orphan"
    )
    settings = relationship(
        "CompanySettings",
        back_populates="company",
        uselist=False,
        cascade="all, delete-orphan",
    )
    user_roles = relationship(
        "UserRole", back_populates="company", cascade="all, delete-orphan"
    )


class CompanySettings(Base):
    __tablename__ = "company_settings"
    __table_args__ = {"schema": "tenant"}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    max_users = Column(Integer, default=50)
    max_vehicles = Column(Integer, default=100)
    # basic | professional | enterprise
    subscription_tier = Column(String(50), default="basic")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    company = relationship("Company", back_populates="settings")


class UserRole(Base):
    """Per-company role definitions with JSON permission arrays."""

    __tablename__ = "user_roles"
    __table_args__ = (
        UniqueConstraint("company_id", "role_name", name="uq_company_role"),
        {"schema": "tenant"},
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    company_id = Column(
        UUID(as_uuid=True),
        ForeignKey("tenant.companies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # SUPER_ADMIN | MANAGER | SUPERVISOR | DRIVER
    role_name = Column(String(50), nullable=False)
    permissions = Column(JSON, default=list)
    created_at = Column(DateTime, default=datetime.utcnow)

    company = relationship("Company", back_populates="user_roles")
