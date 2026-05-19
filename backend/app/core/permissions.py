"""
Role-based permission definitions for multi-tenant access control.

Roles (per company):
  SUPER_ADMIN — full access to all features
  MANAGER     — operational management, no user/settings management
  SUPERVISOR  — full trip lifecycle + allocation + expense management
  DRIVER      — read-only trips, own attendance, own expense logging
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
    ],
    "DRIVER": [
        Permission.VIEW_DASHBOARD,
        Permission.VIEW_TRIPS,
        Permission.MANAGE_EXPENSES,
        Permission.VIEW_ATTENDANCE,
        Permission.MANAGE_ATTENDANCE,
    ],
}


def check_permission(user_role: str, required_permission: Permission) -> bool:
    """Return True if the given role includes the required permission."""
    permissions = ROLE_PERMISSIONS.get(user_role, [])
    return required_permission in permissions
