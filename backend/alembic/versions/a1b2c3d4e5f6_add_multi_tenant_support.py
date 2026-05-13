"""add_multi_tenant_support

Revision ID: a1b2c3d4e5f6
Revises: ee2c2b6b204c
Create Date: 2026-05-11 00:00:00.000000

Transforms the single-company ERP into a multi-tenant SaaS platform.

Changes:
  1. Creates 'tenant' PostgreSQL schema
  2. Creates tenant.companies table
  3. Creates tenant.company_settings table
  4. Creates tenant.user_roles table
  5. Adds company_id (UUID FK) to:
       auth.users, master.vehicles, master.drivers, master.routes,
       operations.trips, operations.trip_expenses,
       master.driver_vehicle_assignments
  6. Adds user_role_id (UUID FK) to auth.users
  7. Creates performance indexes
"""

from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from alembic import op


revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "ee2c2b6b204c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()

    # ── 1. Create tenant schema ────────────────────────────────────────────────
    bind.execute(sa.text('CREATE SCHEMA IF NOT EXISTS "tenant"'))

    # ── 2. tenant.companies ────────────────────────────────────────────────────
    op.create_table(
        "companies",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("company_name", sa.String(255), nullable=False),
        sa.Column("owner_name", sa.String(255), nullable=False),
        sa.Column("mobile_number", sa.String(20), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("gst_number", sa.String(20), nullable=True),
        sa.Column("address", sa.Text, nullable=True),
        sa.Column("logo_url", sa.String(500), nullable=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default="true"),
        sa.Column(
            "created_at",
            sa.DateTime,
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime,
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.UniqueConstraint("company_name", name="uq_companies_name"),
        sa.UniqueConstraint("email", name="uq_companies_email"),
        schema="tenant",
    )
    op.create_index(
        "ix_tenant_companies_company_name",
        "companies",
        ["company_name"],
        schema="tenant",
    )
    op.create_index(
        "ix_tenant_companies_email", "companies", ["email"], schema="tenant"
    )
    op.create_index(
        "ix_tenant_companies_is_active", "companies", ["is_active"], schema="tenant"
    )

    # ── 3. tenant.company_settings ─────────────────────────────────────────────
    op.create_table(
        "company_settings",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "company_id",
            UUID(as_uuid=True),
            sa.ForeignKey("tenant.companies.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("max_users", sa.Integer, nullable=False, server_default="50"),
        sa.Column("max_vehicles", sa.Integer, nullable=False, server_default="100"),
        sa.Column(
            "subscription_tier",
            sa.String(50),
            nullable=False,
            server_default="basic",
        ),
        sa.Column(
            "created_at",
            sa.DateTime,
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime,
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        schema="tenant",
    )

    # ── 4. tenant.user_roles ───────────────────────────────────────────────────
    op.create_table(
        "user_roles",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "company_id",
            UUID(as_uuid=True),
            sa.ForeignKey("tenant.companies.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("role_name", sa.String(50), nullable=False),
        sa.Column("permissions", sa.JSON, nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime,
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.UniqueConstraint("company_id", "role_name", name="uq_company_role"),
        schema="tenant",
    )
    op.create_index(
        "ix_tenant_user_roles_company_id",
        "user_roles",
        ["company_id"],
        schema="tenant",
    )

    # ── 5. Add company_id to auth.users ────────────────────────────────────────
    op.add_column(
        "users",
        sa.Column("company_id", UUID(as_uuid=True), nullable=True),
        schema="auth",
    )
    op.add_column(
        "users",
        sa.Column("user_role_id", UUID(as_uuid=True), nullable=True),
        schema="auth",
    )
    op.create_foreign_key(
        "fk_users_company_id",
        "users",
        "companies",
        ["company_id"],
        ["id"],
        source_schema="auth",
        referent_schema="tenant",
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_users_user_role_id",
        "users",
        "user_roles",
        ["user_role_id"],
        ["id"],
        source_schema="auth",
        referent_schema="tenant",
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_auth_users_company_id", "users", ["company_id"], schema="auth"
    )
    op.create_index(
        "ix_auth_users_company_email",
        "users",
        ["company_id", "email"],
        schema="auth",
    )

    # ── 6. Add company_id to master.vehicles ───────────────────────────────────
    op.add_column(
        "vehicles",
        sa.Column("company_id", UUID(as_uuid=True), nullable=True),
        schema="master",
    )
    op.create_foreign_key(
        "fk_vehicles_company_id",
        "vehicles",
        "companies",
        ["company_id"],
        ["id"],
        source_schema="master",
        referent_schema="tenant",
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_master_vehicles_company_id",
        "vehicles",
        ["company_id"],
        schema="master",
    )
    op.create_index(
        "ix_master_vehicles_company_status",
        "vehicles",
        ["company_id", "status"],
        schema="master",
    )

    # ── 7. Add company_id to master.drivers ────────────────────────────────────
    op.add_column(
        "drivers",
        sa.Column("company_id", UUID(as_uuid=True), nullable=True),
        schema="master",
    )
    op.create_foreign_key(
        "fk_drivers_company_id",
        "drivers",
        "companies",
        ["company_id"],
        ["id"],
        source_schema="master",
        referent_schema="tenant",
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_master_drivers_company_id",
        "drivers",
        ["company_id"],
        schema="master",
    )

    # ── 8. Add company_id to master.routes ─────────────────────────────────────
    op.add_column(
        "routes",
        sa.Column("company_id", UUID(as_uuid=True), nullable=True),
        schema="master",
    )
    op.create_foreign_key(
        "fk_routes_company_id",
        "routes",
        "companies",
        ["company_id"],
        ["id"],
        source_schema="master",
        referent_schema="tenant",
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_master_routes_company_id",
        "routes",
        ["company_id"],
        schema="master",
    )

    # ── 9. Add company_id to operations.trips ──────────────────────────────────
    op.add_column(
        "trips",
        sa.Column("company_id", UUID(as_uuid=True), nullable=True),
        schema="operations",
    )
    op.create_foreign_key(
        "fk_trips_company_id",
        "trips",
        "companies",
        ["company_id"],
        ["id"],
        source_schema="operations",
        referent_schema="tenant",
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_operations_trips_company_id",
        "trips",
        ["company_id"],
        schema="operations",
    )

    # ── 10. Add company_id to operations.trip_expenses ─────────────────────────
    op.add_column(
        "trip_expenses",
        sa.Column("company_id", UUID(as_uuid=True), nullable=True),
        schema="operations",
    )
    op.create_foreign_key(
        "fk_trip_expenses_company_id",
        "trip_expenses",
        "companies",
        ["company_id"],
        ["id"],
        source_schema="operations",
        referent_schema="tenant",
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_operations_trip_expenses_company_id",
        "trip_expenses",
        ["company_id"],
        schema="operations",
    )

    # ── 11. Add company_id to master.driver_vehicle_assignments ────────────────
    op.add_column(
        "driver_vehicle_assignments",
        sa.Column("company_id", UUID(as_uuid=True), nullable=True),
        schema="master",
    )
    op.create_foreign_key(
        "fk_assignments_company_id",
        "driver_vehicle_assignments",
        "companies",
        ["company_id"],
        ["id"],
        source_schema="master",
        referent_schema="tenant",
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_master_assignments_company_id",
        "driver_vehicle_assignments",
        ["company_id"],
        schema="master",
    )


def downgrade() -> None:
    # ── Remove indexes and FKs from operational tables ─────────────────────────
    op.drop_index(
        "ix_master_assignments_company_id",
        table_name="driver_vehicle_assignments",
        schema="master",
    )
    op.drop_constraint(
        "fk_assignments_company_id",
        "driver_vehicle_assignments",
        schema="master",
        type_="foreignkey",
    )
    op.drop_column("driver_vehicle_assignments", "company_id", schema="master")

    op.drop_index(
        "ix_operations_trip_expenses_company_id",
        table_name="trip_expenses",
        schema="operations",
    )
    op.drop_constraint(
        "fk_trip_expenses_company_id",
        "trip_expenses",
        schema="operations",
        type_="foreignkey",
    )
    op.drop_column("trip_expenses", "company_id", schema="operations")

    op.drop_index(
        "ix_operations_trips_company_id", table_name="trips", schema="operations"
    )
    op.drop_constraint(
        "fk_trips_company_id", "trips", schema="operations", type_="foreignkey"
    )
    op.drop_column("trips", "company_id", schema="operations")

    op.drop_index(
        "ix_master_routes_company_id", table_name="routes", schema="master"
    )
    op.drop_constraint(
        "fk_routes_company_id", "routes", schema="master", type_="foreignkey"
    )
    op.drop_column("routes", "company_id", schema="master")

    op.drop_index(
        "ix_master_drivers_company_id", table_name="drivers", schema="master"
    )
    op.drop_constraint(
        "fk_drivers_company_id", "drivers", schema="master", type_="foreignkey"
    )
    op.drop_column("drivers", "company_id", schema="master")

    op.drop_index(
        "ix_master_vehicles_company_status", table_name="vehicles", schema="master"
    )
    op.drop_index(
        "ix_master_vehicles_company_id", table_name="vehicles", schema="master"
    )
    op.drop_constraint(
        "fk_vehicles_company_id", "vehicles", schema="master", type_="foreignkey"
    )
    op.drop_column("vehicles", "company_id", schema="master")

    op.drop_index(
        "ix_auth_users_company_email", table_name="users", schema="auth"
    )
    op.drop_index(
        "ix_auth_users_company_id", table_name="users", schema="auth"
    )
    op.drop_constraint(
        "fk_users_user_role_id", "users", schema="auth", type_="foreignkey"
    )
    op.drop_constraint(
        "fk_users_company_id", "users", schema="auth", type_="foreignkey"
    )
    op.drop_column("users", "user_role_id", schema="auth")
    op.drop_column("users", "company_id", schema="auth")

    # ── Drop tenant tables ─────────────────────────────────────────────────────
    op.drop_table("user_roles", schema="tenant")
    op.drop_table("company_settings", schema="tenant")
    op.drop_table("companies", schema="tenant")

    bind = op.get_bind()
    bind.execute(sa.text('DROP SCHEMA IF EXISTS "tenant"'))
