from app.db.bootstrap import ensure_database_schemas, repair_existing_schema
from app.db.session import engine, Base

from app.models import (
    Role,
    User,
    Vehicle,
    Driver,
    Route,
    DriverVehicleAssignment,
    Trip,
    TripExpense,
)


def init_db():

    ensure_database_schemas(engine)
    Base.metadata.create_all(bind=engine)
    repair_existing_schema(engine)
