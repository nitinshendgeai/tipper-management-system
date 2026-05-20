"""
Role-based permission definitions for multi-tenant access control.

Roles (per company):
  SUPER_ADMIN — full access to all features
  MANAGER     — operational management, no user/settings management
  SUPERVISOR  — full trip lifecycle + allocation + expense management
  DRIVER      — read-only trips, own attendance, own expense logging

Phase 9 additions:
  MANAGE_MAINTENANCE / VIEW_MAINTENANCE — vehicle maintenance tracking
  MANAGE_FUEL / VIEW_FUEL              — fuel entry management
  MANAGE_DOCUMENTS / VIEW_DOCUMENTS    — document & permit tracking
  VIEW_REPORTS                         — CSV / report export
"""

from enum import Enum
from typing import List


class Permission(str, Enum):
    # Dashboard
    VIEW_DASHBOARD = "view_dashboard"
    VIEW_ANALYTICS = "view_analytics"

    # Users
    MANAGE_USERS = "manage_users"
    VIEW_USERS = "view_users"

    # Vehicles
    MANAGE_VEHICLES = "manage_vehicles"
    VIEW_VEHICLES = "view_vehicles"

    # Drivers
    MANAGE_DRIVERS = "manage_drivers"
    VIEW_DRIVERS = "view_drivers"

    # Routes
    MANAGE_ROUTES = "manage_routes"
    VIEW_ROUTES = "view_routes"

    # Trips
    MANAGE_TRIPS = "manage_trips"
    CREATE_TRIPS = "create_trips"
    VIEW_TRIPS = "view_trips"

    # Finance
    VIEW_FINANCE = "view_finance"
    MANAGE_EXPENSES = "manage_expenses"

    # Attendance
    VIEW_ATTENDANCE = "view_attendance"
    MANAGE_ATTENDANCE = "manage_attendance"

    # Settings
    MANAGE_SETTINGS = "manage_settings"

    # ── Phase 9: Enterprise modules ───────────────────────────────────────────

    # Maintenance management
    MANAGE_MAINTENANCE = "manage_maintenance"
    VIEW_MAINTENANCE = "view_maintenance"

    # Fuel management
    MANAGE_FUEL = "manage_fuel"
    VIEW_FUEL = "view_fuel"

    # Document & permit tracking
    MANAGE_DOCUMENTS = "manage_documents"
    VIEW_DOCUMENTS = "view_documents"

    # Reporting & CSV export
    VIEW_REPORTS = "view_reports"


ROLE_PERMISSIONS: dict[str, List[Permission]] = {
    "SUPER_ADMIN": [
        Permission.VIEW_DASHBOARD,
        Permission.VIEW_ANALYTICS,
        Permission.MANAGE_USERS,
        Permission.VIEW_USERS,
        Permission.MANAGE_VEHICLES,
        Permission.VIEW_VEHICLES,
        Permission.MANAGE_DRIVERS,
        Permission.VIEW_DRIVERS,
        Permission.MANAGE_ROUTES,
        Permission.VIEW_ROUTES,
        Permission.MANAGE_TRIPS,
        Permission.CREATE_TRIPS,
        Permission.VIEW_TRIPS,
        Permission.VIEW_FINANCE,
        Permission.MANAGE_EXPENSES,
        Permission.VIEW_ATTENDANCE,
        Permission.MANAGE_ATTENDANCE,
        Permission.MANAGE_SETTINGS,
        # Phase 9
        Permission.MANAGE_MAINTENANCE,
        Permission.VIEW_MAINTENANCE,
        Permission.MANAGE_FUEL,
        Permission.VIEW_FUEL,
        Permission.MANAGE_DOCUMENTS,
        Permission.VIEW_DOCUMENTS,
        Permission.VIEW_REPORTS,
    ],
    "MANAGER": [
        Permission.VIEW_DASHBOARD,
        Permission.VIEW_ANALYTICS,
        Permission.VIEW_USERS,
        Permission.MANAGE_VEHICLES,
        Permission.VIEW_VEHICLES,
        Permission.MANAGE_DRIVERS,
        Permission.VIEW_DRIVERS,
        Permission.MANAGE_ROUTES,
        Permission.VIEW_ROUTES,
        Permission.MANAGE_TRIPS,
        Permission.CREATE_TRIPS,
        Permission.VIEW_TRIPS,
        Permission.VIEW_FINANCE,
        Permission.MANAGE_EXPENSES,
        Permission.VIEW_ATTENDANCE,
        Permission.MANAGE_ATTENDANCE,
        # Phase 9
        Permission.MANAGE_MAINTENANCE,
        Permission.VIEW_MAINTENANCE,
        Permission.MANAGE_FUEL,
        Permission.VIEW_FUEL,
        Permission.MANAGE_DOCUMENTS,
        Permission.VIEW_DOCUMENTS,
        Permission.VIEW_REPORTS,
    ],
    "SUPERVISOR": [
        Permission.VIEW_DASHBOARD,
        Permission.VIEW_VEHICLES,
        Permission.VIEW_DRIVERS,
        Permission.VIEW_ROUTES,
        Permission.CREATE_TRIPS,
        Permission.MANAGE_TRIPS,    # Phase 7 fix (RBAC-007): SUPERVISOR must be able to
                                    # start/complete/cancel trips and manage allocations.
                                    # Was missing — broke the entire operational workflow.
        Permission.VIEW_TRIPS,
        Permission.MANAGE_EXPENSES,
        Permission.VIEW_ATTENDANCE,
        Permission.MANAGE_ATTENDANCE,
        # Phase 9: Supervisors can log fuel and view maintenance/docs
        Permission.VIEW_MAINTENANCE,
        Permission.MANAGE_FUEL,
        Permission.VIEW_FUEL,
        Permission.VIEW_DOCUMENTS,
    ],
    "DRIVER": [
        Permission.VIEW_DASHBOARD,
        Permission.VIEW_TRIPS,
        Permission.MANAGE_EXPENSES,
        Permission.VIEW_ATTENDANCE,
        Permission.MANAGE_ATTENDANCE,
        # Phase 9: Drivers can view their own fuel entries and documents
        Permission.VIEW_FUEL,
        Permission.VIEW_DOCUMENTS,
    ],
}


def check_permission(user_role: str, required_permission: Permission) -> bool:
    """Return True if the given role includes the required permission."""
    permissions = ROLE_PERMISSIONS.get(user_role, [])
    return required_permission in permissions
