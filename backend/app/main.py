from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db.seed import seed_data
from app.db.session import Base, engine

from app.api.auth_api import router as auth_router
from app.api.admin_api import router as admin_router

from app.api.vehicle_api import router as vehicle_router
from app.api.driver_api import router as driver_router
from app.api.route_api import router as route_router

from app.api.allocation_api import router as allocation_router
from app.api.route_intelligence_api import router as route_intelligence_router

from app.api.trip_api import router as trip_router
from app.api.trip_expense_api import router as trip_expense_router

from app.api.dashboard_api import router as dashboard_router


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
    Base.metadata.create_all(bind=engine)
    seed_data()


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


# ─── Dashboard ────────────────────────────────────────────────────────────────

app.include_router(
    dashboard_router,
    prefix="/dashboard",
    tags=["Dashboard Analytics"]
)
