from sqlalchemy import text
from sqlalchemy.engine import Engine


POSTGRES_SCHEMAS = ("auth", "master", "operations", "tenant")


def ensure_database_schemas(engine: Engine) -> None:
    """Create PostgreSQL schemas required by the SQLAlchemy models."""
    if engine.dialect.name != "postgresql":
        return

    with engine.begin() as connection:
        for schema in POSTGRES_SCHEMAS:
            connection.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{schema}"'))


def repair_existing_schema(engine: Engine) -> None:
    """Bring older PostgreSQL databases up to the current model shape."""
    if engine.dialect.name != "postgresql":
        return

    statements = [
        "ALTER TABLE IF EXISTS master.vehicles ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE'",
        "ALTER TABLE IF EXISTS master.drivers ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'OFF_DUTY'",
        "ALTER TABLE IF EXISTS master.routes ADD COLUMN IF NOT EXISTS remarks VARCHAR(255)",
        "ALTER TABLE IF EXISTS operations.trips ALTER COLUMN route_id DROP NOT NULL",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS source_location VARCHAR(255)",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS destination_location VARCHAR(255)",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS calculated_distance_km DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS estimated_duration_min INTEGER",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS estimated_diesel DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS distance_km_override DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS start_km DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS end_km DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS diesel_issued DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS trip_advance DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS toll_expense DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS driver_bata DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS revenue_amount DOUBLE PRECISION",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP",
        "ALTER TABLE IF EXISTS operations.trips ADD COLUMN IF NOT EXISTS cancellation_reason VARCHAR(255)",
        # Phase 4: link driver profile to auth.users for DRIVER self-attendance
        "ALTER TABLE IF EXISTS master.drivers ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES auth.users(id) ON DELETE SET NULL",

        # ── Phase 6: Performance indexes ──────────────────────────────────────
        # company_id indexes — core of multi-tenant isolation
        "CREATE INDEX IF NOT EXISTS idx_vehicles_company_id ON master.vehicles (company_id)",
        "CREATE INDEX IF NOT EXISTS idx_drivers_company_id ON master.drivers (company_id)",
        "CREATE INDEX IF NOT EXISTS idx_routes_company_id ON master.routes (company_id)",
        "CREATE INDEX IF NOT EXISTS idx_assignments_company_id ON master.driver_vehicle_assignments (company_id)",
        "CREATE INDEX IF NOT EXISTS idx_trips_company_id ON operations.trips (company_id)",
        "CREATE INDEX IF NOT EXISTS idx_trip_expenses_company_id ON operations.trip_expenses (company_id)",
        "CREATE INDEX IF NOT EXISTS idx_attendance_company_id ON operations.attendance (company_id)",

        # trip_status index — heavily queried in list, analytics, and alerts
        "CREATE INDEX IF NOT EXISTS idx_trips_trip_status ON operations.trips (trip_status)",

        # trip_date index — used by all time-windowed analytics queries
        "CREATE INDEX IF NOT EXISTS idx_trips_trip_date ON operations.trips (trip_date)",

        # Composite: company + status — the most common dashboard query pattern
        "CREATE INDEX IF NOT EXISTS idx_trips_company_status ON operations.trips (company_id, trip_status)",
        "CREATE INDEX IF NOT EXISTS idx_trips_company_date ON operations.trips (company_id, trip_date)",
        "CREATE INDEX IF NOT EXISTS idx_vehicles_company_status ON master.vehicles (company_id, status)",
        "CREATE INDEX IF NOT EXISTS idx_drivers_company_status ON master.drivers (company_id, status)",

        # attendance shift_date — attendance queries always filter by date
        "CREATE INDEX IF NOT EXISTS idx_attendance_shift_date ON operations.attendance (shift_date)",
        "CREATE INDEX IF NOT EXISTS idx_attendance_driver_date ON operations.attendance (driver_id, shift_date)",

        # active assignment lookup — queried on every trip creation
        "CREATE INDEX IF NOT EXISTS idx_assignments_vehicle_active ON master.driver_vehicle_assignments (vehicle_id, is_active)",

        # ── Phase 6: Fix BIZ-003 + BIZ-004 — per-company unique constraints ──
        # Drop global unique constraints and replace with composite ones.
        # Wrapped in DO blocks so they are idempotent (safe on re-run).
        """
        DO $$
        BEGIN
            -- BIZ-004: vehicle_number unique per company (not globally)
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'uq_vehicles_company_vehicle_number'
            ) THEN
                ALTER TABLE master.vehicles
                    ADD CONSTRAINT uq_vehicles_company_vehicle_number
                    UNIQUE (company_id, vehicle_number);
            END IF;
        END $$;
        """,
        """
        DO $$
        BEGIN
            -- BIZ-003: license_number unique per company (not globally)
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'uq_drivers_company_license_number'
            ) THEN
                ALTER TABLE master.drivers
                    ADD CONSTRAINT uq_drivers_company_license_number
                    UNIQUE (company_id, license_number);
            END IF;
        END $$;
        """,
    ]

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
