"""
Automation Service — Phase 10: Operational Automation Foundation.
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

AUTOMATION_INTERVAL_SECONDS = int(os.getenv("AUTOMATION_INTERVAL_SECONDS", "300"))
OVERDUE_TRIP_HOURS = int(os.getenv("OVERDUE_TRIP_HOURS", "8"))


def _sync_vehicle_availability(db: Session) -> int:
    active_trip_vehicle_ids = (
        db.query(Trip.vehicle_id)
        .filter(Trip.trip_status.in_([TripStatus.CREATED, TripStatus.STARTED]), Trip.vehicle_id != None)
        .distinct().subquery()
    )
    stuck = db.query(Vehicle).filter(
        Vehicle.status.in_([VehicleStatus.ON_TRIP, VehicleStatus.ASSIGNED]),
        Vehicle.is_active == True,
        ~Vehicle.id.in_(active_trip_vehicle_ids),
    ).all()
    for v in stuck:
        v.status = VehicleStatus.AVAILABLE
        logger.info("[automation] vehicle %s freed → AVAILABLE", v.vehicle_number)
    if stuck:
        db.commit()
    return len(stuck)


def _sync_driver_availability(db: Session) -> int:
    active_trip_driver_ids = (
        db.query(Trip.driver_id)
        .filter(Trip.trip_status.in_([TripStatus.CREATED, TripStatus.STARTED]), Trip.driver_id != None)
        .distinct().subquery()
    )
    stuck = db.query(Driver).filter(
        Driver.status == DriverStatus.ON_TRIP,
        Driver.is_active == True,
        ~Driver.id.in_(active_trip_driver_ids),
    ).all()
    for d in stuck:
        d.status = DriverStatus.AVAILABLE
        logger.info("[automation] driver %s freed → AVAILABLE", d.full_name)
    if stuck:
        db.commit()
    return len(stuck)


def _log_overdue_trips(db: Session) -> int:
    cutoff = datetime.utcnow() - timedelta(hours=OVERDUE_TRIP_HOURS)
    overdue = db.query(Trip).filter(
        Trip.trip_status == TripStatus.STARTED,
        Trip.start_time <= cutoff,
        Trip.start_time != None,
    ).all()
    for trip in overdue:
        hours = round((datetime.utcnow() - trip.start_time).total_seconds() / 3600, 1)
        logger.warning("[automation] OVERDUE TRIP id=%s active %.1fh", trip.id, hours)
    return len(overdue)


def run_automation_cycle() -> dict:
    db = SessionLocal()
    summary = {"ran_at": datetime.utcnow().isoformat(), "vehicles_freed": 0, "drivers_freed": 0, "overdue_trips": 0, "error": None}
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
    logger.info("[automation] scheduler started — interval=%ds", AUTOMATION_INTERVAL_SECONDS)
    time.sleep(30)
    while True:
        try:
            summary = run_automation_cycle()
            if any([summary["vehicles_freed"], summary["drivers_freed"], summary["overdue_trips"]]):
                logger.info("[automation] cycle complete — %s", summary)
        except Exception as e:
            logger.error("[automation] loop error: %s", e, exc_info=True)
        time.sleep(AUTOMATION_INTERVAL_SECONDS)
