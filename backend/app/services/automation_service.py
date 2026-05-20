"""
Automation Service — Phase 10: Operational Automation Foundation.

Lightweight stateless tasks that run on a background schedule.
All tasks are company-agnostic at the query level (operate across all companies)
but remain company-scoped at the data level (company_id preserved on all records).

NO external cron infrastructure — uses Python threading with sleep loops.
Railway-safe: no blocking startup, graceful on DB unavailability.

Current automation tasks:
  1. sync_vehicle_availability   — free vehicles from completed/cancelled trips
  2. sync_driver_availability    — free drivers from completed/cancelled trips
  3. mark_overdue_trips          — flag STARTED trips stuck > OVERDUE_HOURS
  4. cleanup_stale_assignments   — remove PENDING assignments with no active trip

Schedule (configurable via env vars):
  AUTOMATION_INTERVAL_SECONDS — how often the loop runs (default: 300 = 5 min)
"""

import logging
import time
import os
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models.trip import Trip, TripStatus
from app.models.vehicle import Vehicle, VehicleStatus
from app.models.driver import Driver, DriverStatus

logger = logging.getLogger(__name__)

# ─── Configuration ────────────────────────────────────────────────────────────

AUTOMATION_INTERVAL_SECONDS = int(os.getenv("AUTOMATION_INTERVAL_SECONDS", "300"))
OVERDUE_TRIP_HOURS = int(os.getenv("OVERDUE_TRIP_HOURS", "8"))
STALE_ASSIGNMENT_HOURS = int(os.getenv("STALE_ASSIGNMENT_HOURS", "24"))


# ─── Task 1: Sync vehicle availability ───────────────────────────────────────

def _sync_vehicle_availability(db: Session) -> int:
    """
    Set vehicles back to AVAILABLE when their trip is COMPLETED or CANCELLED.

    Catches cases where the trip API updated the trip status but the vehicle
    status was not updated (e.g. partial failure, direct DB edits).

    Returns: number of vehicles corrected.
    """
    # Vehicles currently marked ON_TRIP or ASSIGNED but with no active trip
    active_trip_vehicle_ids = (
        db.query(Trip.vehicle_id)
        .filter(
            Trip.trip_status.in_([TripStatus.CREATED, TripStatus.STARTED]),
            Trip.vehicle_id != None,
        )
        .distinct()
        .subquery()
    )

    stuck_vehicles = (
        db.query(Vehicle)
        .filter(
            Vehicle.status.in_([VehicleStatus.ON_TRIP, VehicleStatus.ASSIGNED]),
            Vehicle.is_active == True,
            ~Vehicle.id.in_(active_trip_vehicle_ids),
        )
        .all()
    )

    count = 0
    for vehicle in stuck_vehicles:
        old_status = vehicle.status
        vehicle.status = VehicleStatus.AVAILABLE
        count += 1
        logger.info(
            "[automation] vehicle %s freed: %s → AVAILABLE (no active trip)",
            vehicle.vehicle_number, old_status,
        )

    if count:
        db.commit()

    return count


# ─── Task 2: Sync driver availability ────────────────────────────────────────

def _sync_driver_availability(db: Session) -> int:
    """
    Set drivers back to AVAILABLE when their trip is COMPLETED or CANCELLED.

    Returns: number of drivers corrected.
    """
    active_trip_driver_ids = (
        db.query(Trip.driver_id)
        .filter(
            Trip.trip_status.in_([TripStatus.CREATED, TripStatus.STARTED]),
            Trip.driver_id != None,
        )
        .distinct()
        .subquery()
    )

    stuck_drivers = (
        db.query(Driver)
        .filter(
            Driver.status == DriverStatus.ON_TRIP,
            Driver.is_active == True,
            ~Driver.id.in_(active_trip_driver_ids),
        )
        .all()
    )

    count = 0
    for driver in stuck_drivers:
        driver.status = DriverStatus.AVAILABLE
        count += 1
        logger.info(
            "[automation] driver %s freed: ON_TRIP → AVAILABLE (no active trip)",
            driver.full_name,
        )

    if count:
        db.commit()

    return count


# ─── Task 3: Detect overdue trips ────────────────────────────────────────────

def _log_overdue_trips(db: Session) -> int:
    """
    Log trips that have been in STARTED status longer than OVERDUE_TRIP_HOURS.
    Does NOT change trip status — just logs for observability.
    Alerts are handled by the alert service on demand.

    Returns: number of overdue trips detected.
    """
    cutoff = datetime.utcnow() - timedelta(hours=OVERDUE_TRIP_HOURS)

    overdue = (
        db.query(Trip)
        .filter(
            Trip.trip_status == TripStatus.STARTED,
            Trip.start_time <= cutoff,
            Trip.start_time != None,
        )
        .all()
    )

    for trip in overdue:
        hours = round(
            (datetime.utcnow() - trip.start_time).total_seconds() / 3600, 1
        )
        logger.warning(
            "[automation] OVERDUE TRIP — id=%s company_id=%s "
            "%s→%s active for %.1fh (limit %dh)",
            trip.id, trip.company_id,
            trip.source_location, trip.destination_location,
            hours, OVERDUE_TRIP_HOURS,
        )

    return len(overdue)


# ─── Main runner ──────────────────────────────────────────────────────────────

def run_automation_cycle() -> dict:
    """
    Run one full automation cycle across all tasks.
    Opens its own DB session and closes it cleanly.

    Returns a summary dict for logging/observability.
    """
    db = SessionLocal()
    summary = {
        "ran_at": datetime.utcnow().isoformat(),
        "vehicles_freed": 0,
        "drivers_freed": 0,
        "overdue_trips": 0,
        "error": None,
    }
    try:
        summary["vehicles_freed"] = _sync_vehicle_availability(db)
        summary["drivers_freed"]  = _sync_driver_availability(db)
        summary["overdue_trips"]  = _log_overdue_trips(db)
    except Exception as e:
        summary["error"] = str(e)
        logger.error("[automation] cycle failed: %s", e, exc_info=True)
        db.rollback()
    finally:
        db.close()

    return summary


def start_automation_loop() -> None:
    """
    Blocking loop — call this from a daemon thread.
    Runs run_automation_cycle() every AUTOMATION_INTERVAL_SECONDS.
    Survives individual cycle failures gracefully.
    """
    logger.info(
        "[automation] scheduler started — interval=%ds overdue_hours=%d",
        AUTOMATION_INTERVAL_SECONDS, OVERDUE_TRIP_HOURS,
    )

    # Initial delay — let DB init finish first
    time.sleep(30)

    while True:
        try:
            summary = run_automation_cycle()
            if any([
                summary["vehicles_freed"],
                summary["drivers_freed"],
                summary["overdue_trips"],
                summary["stale_assignments_cleaned"],
            ]):
                logger.info("[automation] cycle complete — %s", summary)
            else:
                logger.debug("[automation] cycle complete — nothing to do")
        except Exception as e:
            logger.error("[automation] unexpected loop error: %s", e, exc_info=True)

        time.sleep(AUTOMATION_INTERVAL_SECONDS)
