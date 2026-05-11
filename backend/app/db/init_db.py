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

    Base.metadata.create_all(bind=engine)