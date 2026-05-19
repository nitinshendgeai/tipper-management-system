import logging
import logging.config
import threading
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

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
from app.api.analytics_api import router as analytics_router

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


# ─── Logging configuration ────────────────────────────────────────────────────
# Structured logging to stdout — Railway picks this up in the Logs tab.
# Do NOT log credentials, passwords, or tokens.

logging.config.dictConfig({
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {
            "format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            "datefmt": "%Y-%m-%d %H:%M:%S",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "default",
            "stream": "ext://sys.stdout",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
    "loggers": {
        "uvicorn.access": {"level": "WARNING"},
        "sqlalchemy.engine": {"level": "WARNING"},
    },
})

logger = logging.getLogger(__name__)


# ─── Background initialisation state ─────────────────────────────────────────
# ALL database work runs here — after the process is already serving requests.
# This means Railway healthcheck passes immediately even on a cold DB.

_bg_init: dict = {
    "started": False,
    "complete": False,
    "error": None,
    "steps_done": [],
    "elapsed_s": None,
}


def _run_background_init() -> None:
    """
    ALL database initialisation — runs in a daemon thread after the FastAPI
    process is already alive and /health is responding.

    Why everything is deferred:
      Even 'fast' operations like ensure_database_schemas() and
      Base.metadata.create_all() open a real DB connection. On Railway a
      cold-start container may try to connect before the Postgres service is
      fully ready, raising OperationalError and crashing the process before
      a single request is ever served — which causes the healthcheck to fail
      with 'service unavailable'.

    Keeping startup() completely DB-free guarantees the process survives even
    if the database is temporarily unreachable. The background thread will
    retry-log and complete once the DB is available.

    Steps (all idempotent — safe to run on every restart):
      1. ensure_database_schemas  — CREATE SCHEMA IF NOT EXISTS ×4
      2. Base.metadata.create_all — CREATE TABLE IF NOT EXISTS ×N
      3. repair_existing_schema   — ALTER TABLE + CREATE INDEX + DO blocks
      4. seed_data                — legacy roles + admin user
    """
    _bg_init["started"] = True
    t0 = time.perf_counter()

    try:
        logger.info("[bg-init] ── Database initialisation starting ──")

        # 1. Schemas
        t1 = time.perf_counter()
        logger.info("[bg-init] 1/4 — ensure_database_schemas()")
        ensure_database_schemas(engine)
        _bg_init["steps_done"].append("schemas")
        logger.info("[bg-init] 1/4 — done (%.2fs)", time.perf_counter() - t1)

        # 2. Tables
        t2 = time.perf_counter()
        logger.info("[bg-init] 2/4 — Base.metadata.create_all()")
        Base.metadata.create_all(bind=engine)
        _bg_init["steps_done"].append("tables")
        logger.info("[bg-init] 2/4 — done (%.2fs)", time.perf_counter() - t2)

        # 3. Column backfills, indexes, unique constraints
        t3 = time.perf_counter()
        logger.info("[bg-init] 3/4 — repair_existing_schema() (ALTER TABLE + CREATE INDEX)")
        repair_existing_schema(engine)
        _bg_init["steps_done"].append("repair_schema")
        logger.info("[bg-init] 3/4 — done (%.2fs)", time.perf_counter() - t3)

        # 4. Seed legacy roles + admin user
        t4 = time.perf_counter()
        logger.info("[bg-init] 4/4 — seed_data()")
        seed_data()
        _bg_init["steps_done"].append("seed_data")
        logger.info("[bg-init] 4/4 — done (%.2fs)", time.perf_counter() - t4)

        total = time.perf_counter() - t0
        _bg_init["complete"] = True
        _bg_init["elapsed_s"] = round(total, 2)
        logger.info("[bg-init] ── Database initialisation complete in %.2fs ──", total)

    except Exception as exc:
        _bg_init["error"] = f"{type(exc).__name__}: {exc}"
        logger.error("[bg-init] Database initialisation FAILED: %s", exc, exc_info=True)


# ─── FastAPI app ──────────────────────────────────────────────────────────────

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


# ─── Global exception handler ─────────────────────────────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(
        "Unhandled exception on %s %s: %s",
        request.method, request.url.path, repr(exc),
        exc_info=True,
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "An unexpected server error occurred. "
                      "The operations team has been notified.",
            "path": str(request.url.path),
        },
    )


# ─── Health endpoint ──────────────────────────────────────────────────────────
# MUST be defined before @app.on_event("startup") so it is registered and
# reachable the instant uvicorn accepts connections — before startup() runs.
# Zero DB calls — responds in <1 ms no matter what state the DB is in.

@app.get("/health", tags=["Health"], summary="Healthcheck — zero DB, always fast")
def health_check():
    """
    Used by Railway (healthcheckPath = '/health').
    Returns HTTP 200 as soon as the process is alive.
    DB init progress is included for observability but never affects status.
    """
    return {
        "status": "ok",
        "db_init_complete": _bg_init["complete"],
        "db_init_error": _bg_init["error"],
        "db_init_steps_done": _bg_init["steps_done"],
        "db_init_elapsed_s": _bg_init["elapsed_s"],
    }


# ─── Startup event ────────────────────────────────────────────────────────────
# ZERO database work here. The only job of startup() is to launch the
# background thread. The process becomes healthy in milliseconds.

@app.on_event("startup")
def startup() -> None:
    logger.info("=== Tipper ERP API — process started, launching DB init thread ===")

    thread = threading.Thread(
        target=_run_background_init,
        name="db-init",
        daemon=True,  # won't block process exit if still running
    )
    thread.start()

    logger.info("=== Tipper ERP API — serving requests. DB init running in background. ===")


# ─── Routers ──────────────────────────────────────────────────────────────────

app.include_router(company_router,           prefix="/companies",        tags=["Company Management"])
app.include_router(auth_router,              prefix="/auth",             tags=["Authentication"])
app.include_router(admin_router,             prefix="/admin",            tags=["Admin"])
app.include_router(vehicle_router,           prefix="/vehicles",         tags=["Vehicle Master"])
app.include_router(driver_router,            prefix="/drivers",          tags=["Driver Master"])
app.include_router(route_router,             prefix="/routes",           tags=["Route Master"])
app.include_router(allocation_router,        prefix="/allocations",      tags=["Shift Allocation"])
app.include_router(route_intelligence_router,prefix="/route-intelligence",tags=["AI Route Intelligence"])
app.include_router(trip_router,              prefix="/trips",            tags=["Trip Operations"])
app.include_router(trip_expense_router,      prefix="/trips",            tags=["Trip Expenses"])
app.include_router(attendance_router,        prefix="/attendance",       tags=["Driver Attendance"])
app.include_router(dashboard_router,         prefix="/dashboard",        tags=["Dashboard Analytics"])
app.include_router(analytics_router,         prefix="/analytics",        tags=["Analytics & Intelligence"])
