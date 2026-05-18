from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db.bootstrap import ensure_database_schemas, repair_existing_schema
from app.db.seed import seed_data
from app.db.session import Base, engine

from app.api.auth_api import router as auth_router
from app.api.admin_api import router as admin_router
from app.api.company_api import router as company_router

from app.api.vehicle_api import router as vehicle_router
from app.api.driver_api import router as driver_router
from app.api.route_api import router as route_router

from app.api.allocation_api import router as allocation_router
from app.api.route_intelligence_api import router as route_intelligence_router

from app.api.trip_api import router as trip_router
from app.api.trip_expense_api import router as trip_expense_router

from app.api.dashboard_api import router as dashboard_router
from app.api.attendance_api import router as attendance_router

from app.models.company import Company, CompanySettings, UserRole
from app.models.user import User
from app.models.role import Role

from app.models.vehicle import Vehicle
from app.models.driver import Driver
from app.models.route import Route

from app.models.trip import Trip
from app.models.trip_expense import TripExpense

from app.models.assignment import DriverVehicleAssignment
from app.models.attendance import DriverAttendance



app = FastAPI(
    title="Tipper ERP API",
    description="Intelligent Operational Fleet ERP — FastAPI backend",
    version="2.0.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    print("[startup] Startup event triggered")

    # Step 1: Ensure PostgreSQL schemas exist before table creation
    # ensure_database_schemas was imported but not called — fixed in Phase 2 (START-001)
    print("[startup] Ensuring PostgreSQL schemas exist (auth, master, operations, tenant)")
    ensure_database_schemas(engine)

    # Step 2: Create all tables from ORM models
    print("[startup] Running Base.metadata.create_all()")
    Base.metadata.create_all(bind=engine)

    # Step 3: Apply safe column repairs for older database instances
    # repair_existing_schema was imported but not called — fixed in Phase 2 (START-001)
    print("[startup] Running repair_existing_schema() for column backfill")
    repair_existing_schema(engine)

    # Step 4: Seed legacy single-tenant roles and admin user
    print("[startup] Calling seed_data()")
    seed_data()


# ─── Company Registration (public) ───────────────────────────────────────────

app.include_router(
    company_router,
    prefix="/companies",
    tags=["Company Management"]
)


# ─── Authentication ───────────────────────────────────────────────────────────

app.include_router(
    auth_router,
    prefix="/auth",
    tags=["Authentication"]
)

app.include_router(
    admin_router,
    prefix="/admin",
    tags=["Admin"]
)


# ─── Master Data ──────────────────────────────────────────────────────────────

app.include_router(
    vehicle_router,
    prefix="/vehicles",
    tags=["Vehicle Master"]
)

app.include_router(
    driver_router,
    prefix="/drivers",
    tags=["Driver Master"]
)

app.include_router(
    route_router,
    prefix="/routes",
    tags=["Route Master"]
)


# ─── Operational Workflow ─────────────────────────────────────────────────────

app.include_router(
    allocation_router,
    prefix="/allocations",
    tags=["Shift Allocation"]
)

app.include_router(
    route_intelligence_router,
    prefix="/route-intelligence",
    tags=["AI Route Intelligence"]
)

app.include_router(
    trip_router,
    prefix="/trips",
    tags=["Trip Operations"]
)

app.include_router(
    trip_expense_router,
    prefix="/trips",
    tags=["Trip Expenses"]
)


# ─── Attendance ───────────────────────────────────────────────────────────────

app.include_router(
    attendance_router,
    prefix="/attendance",
    tags=["Driver Attendance"]
)


# ─── Dashboard ────────────────────────────────────────────────────────────────

app.include_router(
    dashboard_router,
    prefix="/dashboard",
    tags=["Dashboard Analytics"]
)
