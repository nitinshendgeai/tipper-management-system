"""
Alert Service — Phase 5: Smart Alert Foundation.

Detects operational anomalies and returns structured OperationalAlert objects.
All alerts are company-scoped and stateless — computed fresh on each request.

Designed for future extensibility:
  - Push notifications (FCM / APNs)
  - Email alerts via SMTP
  - Slack/Teams webhook payloads
  - AI anomaly detection training data

Current alert types:
  OVERDUE_TRIP       — trip in STARTED status for too long (> 8 hours)
  EXCESSIVE_EXPENSE  — single trip expense > threshold (Rs.10,000)
  LOW_ATTENDANCE     — fewer than N drivers punched in today vs. active fleet
  INACTIVE_VEHICLE   — vehicle AVAILABLE but no trips in last 7 days
  INACTIVE_DRIVER    — driver AVAILABLE but no trips in last 7 days
  HIGH_CANCELLATION  — >20% trip cancellation rate this week
  DOCUMENT_EXPIRY    — document expiring within 30 days or already expired
  MAINTENANCE_DUE    — scheduled maintenance not completed on time
"""

from datetime import date, datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func, exists, and_

from app.models.trip import Trip, TripStatus
from app.models.trip_expense import TripExpense
from app.models.vehicle import Vehicle, VehicleStatus
from app.models.driver import Driver, DriverStatus
from app.models.attendance import DriverAttendance, AttendanceStatus
from app.models.document import DocumentRecord
from app.models.maintenance import VehicleMaintenance, MaintenanceStatus
from app.schemas.analytics_schema import OperationalAlert, AlertType, AlertSeverity
from app.db.tenant_queries import filter_by_company


# ─── Thresholds (tuneable per-company in future) ─────────────────────────────

OVERDUE_TRIP_HOURS        = 8        # trips active > this many hours
EXCESSIVE_EXPENSE_INR     = 10_000   # single expense amount threshold
LOW_ATTENDANCE_PCT        = 50.0     # < this % of drivers on duty = alert
INACTIVE_DAYS             = 7        # vehicle/driver idle for this many days
HIGH_CANCELLATION_PCT     = 20.0     # cancellation rate threshold
DOCUMENT_EXPIRY_WARN_DAYS = 30       # warn this many days before expiry
MAINTENANCE_OVERDUE_DAYS  = 0        # scheduled_date < today = overdue


# ─── Individual detectors ─────────────────────────────────────────────────────

def _detect_overdue_trips(company_id, db: Session) -> list[OperationalAlert]:
    """Trips in STARTED status for more than OVERDUE_TRIP_HOURS hours."""
    cutoff = datetime.utcnow() - timedelta(hours=OVERDUE_TRIP_HOURS)
    overdue = (
        filter_by_company(db.query(Trip), Trip)
        .filter(
            Trip.trip_status == TripStatus.STARTED,
            Trip.start_time <= cutoff,
        )
        .all()
    )
    alerts = []
    for trip in overdue:
        hours = round((datetime.utcnow() - trip.start_time).total_seconds() / 3600, 1)
        alerts.append(OperationalAlert(
            alert_type=AlertType.OVERDUE_TRIP,
            severity=AlertSeverity.HIGH,
            title="Trip Overdue",
            message=(
                f"Trip #{trip.id} ({trip.source_location} to {trip.destination_location}) "
                f"has been active for {hours}h — exceeds {OVERDUE_TRIP_HOURS}h limit."
            ),
            entity_type="trip",
            entity_id=trip.id,
            entity_label=f"Trip #{trip.id}",
            triggered_at=datetime.utcnow(),
        ))
    return alerts


def _detect_excessive_expenses(company_id, db: Session) -> list[OperationalAlert]:
    """Individual expenses that exceed the threshold."""
    today = date.today()
    week_ago = today - timedelta(days=7)

    high = (
        filter_by_company(db.query(TripExpense), TripExpense)
        .join(Trip, TripExpense.trip_id == Trip.id)
        .filter(
            TripExpense.amount >= EXCESSIVE_EXPENSE_INR,
            Trip.trip_date >= week_ago,
        )
        .all()
    )
    alerts = []
    for exp in high:
        alerts.append(OperationalAlert(
            alert_type=AlertType.EXCESSIVE_EXPENSE,
            severity=AlertSeverity.MEDIUM,
            title="Excessive Expense",
            message=(
                f"Expense of Rs.{exp.amount:,.0f} ({exp.expense_type}) on Trip #{exp.trip_id} "
                f"exceeds threshold of Rs.{EXCESSIVE_EXPENSE_INR:,}."
            ),
            entity_type="trip",
            entity_id=exp.trip_id,
            entity_label=f"Trip #{exp.trip_id}",
            triggered_at=datetime.utcnow(),
        ))
    return alerts


def _detect_low_attendance(company_id, db: Session) -> list[OperationalAlert]:
    """Fewer drivers on duty today than expected relative to fleet."""
    total_drivers = (
        filter_by_company(db.query(func.count(Driver.id)), Driver)
        .filter(Driver.is_active == True)
        .scalar() or 0
    )
    if total_drivers == 0:
        return []

    on_duty = (
        filter_by_company(db.query(func.count(DriverAttendance.id)), DriverAttendance)
        .filter(
            DriverAttendance.shift_date == date.today(),
            DriverAttendance.status == AttendanceStatus.PRESENT,
            DriverAttendance.is_active == True,
        )
        .scalar() or 0
    )

    attendance_pct = (on_duty / total_drivers) * 100
    if attendance_pct < LOW_ATTENDANCE_PCT:
        return [OperationalAlert(
            alert_type=AlertType.LOW_ATTENDANCE,
            severity=AlertSeverity.MEDIUM,
            title="Low Driver Attendance",
            message=(
                f"Only {on_duty} of {total_drivers} drivers are on duty today "
                f"({attendance_pct:.0f}% — below {LOW_ATTENDANCE_PCT:.0f}% threshold)."
            ),
            entity_type="fleet",
            entity_label="Driver Attendance",
            triggered_at=datetime.utcnow(),
        )]
    return []


def _detect_inactive_vehicles(company_id, db: Session) -> list[OperationalAlert]:
    """Vehicles in AVAILABLE status with no trips in the last INACTIVE_DAYS days."""
    cutoff = date.today() - timedelta(days=INACTIVE_DAYS)

    recent_trip_exists = (
        exists()
        .where(
            and_(
                Trip.vehicle_id == Vehicle.id,
                Trip.trip_date >= cutoff,
            )
        )
    )

    inactive_vehicles = (
        filter_by_company(db.query(Vehicle), Vehicle)
        .filter(
            Vehicle.is_active == True,
            Vehicle.status == VehicleStatus.AVAILABLE,
            ~recent_trip_exists,
        )
        .all()
    )

    return [
        OperationalAlert(
            alert_type=AlertType.INACTIVE_VEHICLE,
            severity=AlertSeverity.LOW,
            title="Inactive Vehicle",
            message=(
                f"Vehicle {v.vehicle_number} has had no trips in the last {INACTIVE_DAYS} days "
                f"and is currently AVAILABLE."
            ),
            entity_type="vehicle",
            entity_id=v.id,
            entity_label=v.vehicle_number,
            triggered_at=datetime.utcnow(),
        )
        for v in inactive_vehicles
    ]


def _detect_inactive_drivers(company_id, db: Session) -> list[OperationalAlert]:
    """Drivers AVAILABLE with no trips in the last INACTIVE_DAYS days."""
    cutoff = date.today() - timedelta(days=INACTIVE_DAYS)

    recent_trip_exists = (
        exists()
        .where(
            and_(
                Trip.driver_id == Driver.id,
                Trip.trip_date >= cutoff,
            )
        )
    )

    inactive_drivers = (
        filter_by_company(db.query(Driver), Driver)
        .filter(
            Driver.is_active == True,
            Driver.status == DriverStatus.AVAILABLE,
            ~recent_trip_exists,
        )
        .all()
    )

    return [
        OperationalAlert(
            alert_type=AlertType.INACTIVE_DRIVER,
            severity=AlertSeverity.LOW,
            title="Inactive Driver",
            message=(
                f"Driver {d.full_name} has had no trips in the last {INACTIVE_DAYS} days "
                f"and is currently AVAILABLE."
            ),
            entity_type="driver",
            entity_id=d.id,
            entity_label=d.full_name,
            triggered_at=datetime.utcnow(),
        )
        for d in inactive_drivers
    ]


def _detect_high_cancellation(company_id, db: Session) -> list[OperationalAlert]:
    """Trip cancellation rate this week exceeds threshold."""
    monday = date.today() - timedelta(days=date.today().weekday())
    today = date.today()
    week_trips = (
        filter_by_company(db.query(Trip), Trip)
        .filter(Trip.trip_date >= monday, Trip.trip_date <= today)
    )
    total     = week_trips.count()
    cancelled = week_trips.filter(Trip.trip_status == TripStatus.CANCELLED).count()

    if total == 0:
        return []

    cancel_pct = (cancelled / total) * 100
    if cancel_pct >= HIGH_CANCELLATION_PCT:
        return [OperationalAlert(
            alert_type=AlertType.HIGH_CANCELLATION,
            severity=AlertSeverity.HIGH,
            title="High Cancellation Rate",
            message=(
                f"{cancelled} of {total} trips this week were cancelled "
                f"({cancel_pct:.0f}% — above {HIGH_CANCELLATION_PCT:.0f}% threshold)."
            ),
            entity_type="fleet",
            entity_label="Trip Cancellations",
            triggered_at=datetime.utcnow(),
        )]
    return []


def _detect_document_expiry(company_id, db: Session) -> list[OperationalAlert]:
    """
    Documents expiring within DOCUMENT_EXPIRY_WARN_DAYS days, or already expired.
    CRITICAL if expired or expiring today, HIGH if within warning window.
    """
    today = date.today()
    warn_cutoff = today + timedelta(days=DOCUMENT_EXPIRY_WARN_DAYS)

    expiring_docs = (
        filter_by_company(db.query(DocumentRecord), DocumentRecord)
        .filter(
            DocumentRecord.expiry_date != None,
            DocumentRecord.expiry_date <= warn_cutoff,
        )
        .order_by(DocumentRecord.expiry_date)
        .all()
    )

    alerts = []
    for doc in expiring_docs:
        days_left = (doc.expiry_date - today).days
        if days_left < 0:
            severity = AlertSeverity.CRITICAL
            status_str = f"EXPIRED {abs(days_left)} day(s) ago"
        elif days_left == 0:
            severity = AlertSeverity.CRITICAL
            status_str = "expires TODAY"
        else:
            severity = AlertSeverity.HIGH
            status_str = f"expires in {days_left} day(s)"

        alerts.append(OperationalAlert(
            alert_type=AlertType.DOCUMENT_EXPIRY,
            severity=severity,
            title="Document Expiry",
            message=(
                f"{doc.document_name} ({doc.category}) — {status_str}. "
                f"Document number: {doc.document_number or 'N/A'}."
            ),
            entity_type="document",
            entity_id=doc.id,
            entity_label=doc.document_name,
            triggered_at=datetime.utcnow(),
        ))
    return alerts


def _detect_maintenance_overdue(company_id, db: Session) -> list[OperationalAlert]:
    """
    Maintenance records in SCHEDULED or IN_PROGRESS with scheduled_date in the past.
    HIGH if overdue > 3 days, MEDIUM otherwise.
    """
    today = date.today()

    overdue = (
        filter_by_company(db.query(VehicleMaintenance), VehicleMaintenance)
        .join(Vehicle, VehicleMaintenance.vehicle_id == Vehicle.id)
        .filter(
            VehicleMaintenance.status.in_([
                MaintenanceStatus.SCHEDULED,
                MaintenanceStatus.IN_PROGRESS,
            ]),
            VehicleMaintenance.scheduled_date < today,
        )
        .all()
    )

    alerts = []
    for m in overdue:
        days_overdue = (today - m.scheduled_date).days
        alerts.append(OperationalAlert(
            alert_type=AlertType.MAINTENANCE_DUE,
            severity=AlertSeverity.HIGH if days_overdue > 3 else AlertSeverity.MEDIUM,
            title="Maintenance Overdue",
            message=(
                f"{m.maintenance_type} maintenance for vehicle ID {m.vehicle_id} "
                f"was scheduled for {m.scheduled_date} — overdue by {days_overdue} day(s). "
                f"Status: {m.status}."
            ),
            entity_type="vehicle",
            entity_id=m.vehicle_id,
            entity_label=f"Vehicle #{m.vehicle_id}",
            triggered_at=datetime.utcnow(),
        ))
    return alerts


# ─── Main entry point ─────────────────────────────────────────────────────────

def get_operational_alerts(company_id, db: Session) -> list[OperationalAlert]:
    """
    Run all alert detectors and return a combined, severity-sorted list.
    Called by GET /analytics/alerts.

    Severity order: CRITICAL > HIGH > MEDIUM > LOW
    """
    _severity_order = {
        AlertSeverity.CRITICAL: 0,
        AlertSeverity.HIGH:     1,
        AlertSeverity.MEDIUM:   2,
        AlertSeverity.LOW:      3,
    }

    all_alerts: list[OperationalAlert] = []
    all_alerts.extend(_detect_document_expiry(company_id, db))
    all_alerts.extend(_detect_maintenance_overdue(company_id, db))
    all_alerts.extend(_detect_overdue_trips(company_id, db))
    all_alerts.extend(_detect_high_cancellation(company_id, db))
    all_alerts.extend(_detect_excessive_expenses(company_id, db))
    all_alerts.extend(_detect_low_attendance(company_id, db))
    all_alerts.extend(_detect_inactive_vehicles(company_id, db))
    all_alerts.extend(_detect_inactive_drivers(company_id, db))

    all_alerts.sort(key=lambda a: _severity_order.get(a.severity, 9))
    return all_alerts
