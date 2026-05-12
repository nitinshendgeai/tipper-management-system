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
    ]

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
