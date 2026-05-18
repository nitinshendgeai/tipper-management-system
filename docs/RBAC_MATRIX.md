# RBAC Matrix — Tipper Management ERP

**Version:** 3.0.0  
**Last Updated:** 2026-05-18  
**Phase:** System Stabilization — Phase 4 Complete  

---

## Role Definitions

| Role | Scope | Description |
|---|---|---|
| `SUPER_ADMIN` | Per-company | Full access to all features. Company owner/administrator. |
| `MANAGER` | Per-company | Operational management. Cannot manage users or company settings. |
| `SUPERVISOR` | Per-company | Trip creation and expense management. View-only on master data. |
| `DRIVER` | Per-company | View own trips and log expenses only. |

Roles are stored in `tenant.user_roles` per company. Each company gets all 4 roles on registration.

---

## Permission Definitions

Defined in `app/core/permissions.py` as `Permission(str, Enum)`:

| Permission | Value | Description |
|---|---|---|
| `VIEW_DASHBOARD` | `view_dashboard` | Access dashboard stats |
| `VIEW_ANALYTICS` | `view_analytics` | Access analytics data |
| `MANAGE_USERS` | `manage_users` | Create/edit/delete company users |
| `VIEW_USERS` | `view_users` | View company user list |
| `MANAGE_VEHICLES` | `manage_vehicles` | Create/edit/delete vehicles |
| `VIEW_VEHICLES` | `view_vehicles` | View vehicle list |
| `MANAGE_DRIVERS` | `manage_drivers` | Create/edit/delete drivers |
| `VIEW_DRIVERS` | `view_drivers` | View driver list |
| `MANAGE_ROUTES` | `manage_routes` | Create/edit/delete routes |
| `VIEW_ROUTES` | `view_routes` | View route list |
| `MANAGE_TRIPS` | `manage_trips` | Start/complete/cancel trips |
| `CREATE_TRIPS` | `create_trips` | Create new trips |
| `VIEW_TRIPS` | `view_trips` | View trip list and details |
| `VIEW_FINANCE` | `view_finance` | View financial data |
| `MANAGE_EXPENSES` | `manage_expenses` | Add/delete trip expenses |
| `MANAGE_SETTINGS` | `manage_settings` | Modify company settings |
| `VIEW_ATTENDANCE` | `view_attendance` | View attendance records |
| `MANAGE_ATTENDANCE` | `manage_attendance` | Punch in / punch out drivers |

---

## Role → Permission Matrix

| Permission | SUPER_ADMIN | MANAGER | SUPERVISOR | DRIVER |
|---|---|---|---|---|
| VIEW_DASHBOARD | ✅ | ✅ | ✅ | ✅ |
| VIEW_ANALYTICS | ✅ | ✅ | ❌ | ❌ |
| MANAGE_USERS | ✅ | ❌ | ❌ | ❌ |
| VIEW_USERS | ✅ | ✅ | ❌ | ❌ |
| MANAGE_VEHICLES | ✅ | ✅ | ❌ | ❌ |
| VIEW_VEHICLES | ✅ | ✅ | ✅ | ❌ |
| MANAGE_DRIVERS | ✅ | ✅ | ❌ | ❌ |
| VIEW_DRIVERS | ✅ | ✅ | ✅ | ❌ |
| MANAGE_ROUTES | ✅ | ✅ | ❌ | ❌ |
| VIEW_ROUTES | ✅ | ✅ | ✅ | ❌ |
| MANAGE_TRIPS | ✅ | ✅ | ✅ | ❌ |
| CREATE_TRIPS | ✅ | ✅ | ✅ | ❌ |
| VIEW_TRIPS | ✅ | ✅ | ✅ | ✅ |
| VIEW_FINANCE | ✅ | ✅ | ❌ | ❌ |
| MANAGE_EXPENSES | ✅ | ✅ | ✅ | ✅ |
| MANAGE_SETTINGS | ✅ | ❌ | ❌ | ❌ |
| VIEW_ATTENDANCE | ✅ | ✅ | ✅ | ✅ |
| MANAGE_ATTENDANCE | ✅ | ✅ | ✅ | ✅ |

---

## API Endpoint → Permission Map

| Method | Endpoint | Required Permission |
|---|---|---|
| POST | `/companies/register` | None (public) |
| POST | `/auth/login` | None (public) |
| GET | `/auth/me` | Any valid JWT (tenant-aware) |
| POST | `/route-intelligence/calculate` | None (public) |
| POST | `/vehicles/` | MANAGE_VEHICLES |
| GET | `/vehicles/` | VIEW_VEHICLES |
| GET | `/vehicles/{id}` | VIEW_VEHICLES |
| PUT | `/vehicles/{id}` | MANAGE_VEHICLES |
| DELETE | `/vehicles/{id}` | MANAGE_VEHICLES |
| POST | `/drivers/` | MANAGE_DRIVERS |
| GET | `/drivers/` | VIEW_DRIVERS |
| GET | `/drivers/{id}` | VIEW_DRIVERS |
| PUT | `/drivers/{id}` | MANAGE_DRIVERS |
| DELETE | `/drivers/{id}` | MANAGE_DRIVERS |
| POST | `/routes/` | MANAGE_ROUTES |
| GET | `/routes/` | VIEW_ROUTES |
| GET | `/routes/{id}` | VIEW_ROUTES |
| PUT | `/routes/{id}` | MANAGE_ROUTES |
| DELETE | `/routes/{id}` | MANAGE_ROUTES |
| POST | `/allocations/` | MANAGE_VEHICLES |
| GET | `/allocations/active` | VIEW_VEHICLES |
| GET | `/allocations/` | VIEW_VEHICLES |
| GET | `/allocations/{id}` | VIEW_VEHICLES |
| GET | `/allocations/vehicle/{id}` | VIEW_VEHICLES |
| GET | `/allocations/driver/{id}` | VIEW_VEHICLES |
| PUT | `/allocations/{id}/release` | MANAGE_VEHICLES |
| POST | `/trips/` | CREATE_TRIPS |
| GET | `/trips/` | VIEW_TRIPS |
| GET | `/trips/{id}` | VIEW_TRIPS |
| PUT | `/trips/{id}/start` | MANAGE_TRIPS |
| PUT | `/trips/{id}/complete` | MANAGE_TRIPS |
| PUT | `/trips/{id}/cancel` | MANAGE_TRIPS |
| POST | `/trips/{trip_id}/expenses` | MANAGE_EXPENSES |
| GET | `/trips/{trip_id}/expenses` | VIEW_TRIPS |
| DELETE | `/trips/{trip_id}/expenses/{id}` | MANAGE_EXPENSES |
| GET | `/dashboard/stats` | VIEW_DASHBOARD |
| GET | `/admin/dashboard` | Legacy: role_id == 1 (admin_api.py) |
| POST | `/attendance/punch-in` | MANAGE_ATTENDANCE |
| POST | `/attendance/punch-out` | MANAGE_ATTENDANCE |
| GET | `/attendance/me` | VIEW_ATTENDANCE (DRIVER own only) |
| GET | `/attendance/today` | VIEW_ATTENDANCE |
| GET | `/attendance/` | VIEW_ATTENDANCE (MANAGER+) |

---

## Implementation

### Token → Role Resolution

```python
# At login (auth_api.py):
user_role = db.query(UserRole).filter(UserRole.id == user.user_role_id).first()
role_name = user_role.role_name  # "SUPER_ADMIN" | "MANAGER" | "SUPERVISOR" | "DRIVER"

# JWT payload (Phase 3 addition: user_id included):
{ "sub": "email", "user_id": 42, "role_id": 2, "role_name": "MANAGER", "company_id": "uuid" }
```

### Frontend Role Enforcement (Phase 3)

The Flutter app now enforces RBAC on the navigation layer:

```dart
// token_storage.dart — role persisted after login
await TokenStorage.saveRole(roleName);   // e.g. "MANAGER"

// app_drawer.dart — menu visibility by role
bool get _canViewAllocation =>   // SUPERVISOR, MANAGER, SUPER_ADMIN
    _Role.allocationRoles.contains(_roleName);
bool get _canViewMasterData =>   // MANAGER, SUPER_ADMIN only
    _Role.masterDataRoles.contains(_roleName);
```

| Role | Dashboard | Trips | Attendance | Allocation | Vehicles/Drivers/Routes |
|---|---|---|---|---|---|
| DRIVER | ✅ | ✅ (own only) | ✅ (self) | ❌ hidden | ❌ hidden |
| SUPERVISOR | ✅ | ✅ | ✅ (company) | ✅ | ❌ hidden |
| MANAGER | ✅ | ✅ | ✅ (company) | ✅ | ✅ |
| SUPER_ADMIN | ✅ | ✅ | ✅ (company) | ✅ | ✅ |

### Permission Check (dependencies.py)

```python
def require_permission(permission):
    async def _check(user=Depends(get_current_tenant_user)):
        role_name = TenantContext.get_role_name()
        if not check_permission(role_name, permission):
            raise HTTPException(403, "Permission denied")
        return user
    return _check
```

### check_permission (core/permissions.py)

```python
def check_permission(user_role: str, required_permission: Permission) -> bool:
    permissions = ROLE_PERMISSIONS.get(user_role, [])
    return required_permission in permissions
```

---

## Known RBAC Gaps

| Gap | Description | Severity | Status |
|---|---|---|---|
| Admin endpoint uses legacy role_id=1 | `/admin/dashboard` uses `RoleChecker([1])` not RBAC | 🟡 Medium | 📋 Phase 4 |
| No MANAGE_ALLOCATIONS permission | Allocation endpoints reuse MANAGE_VEHICLES — semantically incorrect | 🟢 Low | 📋 Phase 4 |
| No user management API | `MANAGE_USERS` permission exists but no `/users/` endpoint | 🟡 Medium | 📋 Phase 4 |
| `/auth/me` fixed in Phase 2 | Now uses `get_current_tenant_user` for proper isolation | ✅ Fixed | ✅ Phase 2 |
| Frontend auth tokens missing | All GET requests sent without Bearer token | 🔴 Critical | ✅ Fixed Phase 3 |
| Frontend role not persisted | JWT role_name not decoded or stored after login | 🟠 High | ✅ Fixed Phase 3 |
| Drawer shows all items to all roles | No role-based menu visibility | 🟠 High | ✅ Fixed Phase 3 |
| No 401 interceptor in Dio | Expired tokens do not redirect to login screen | 🟡 Medium | ✅ Fixed Phase 4 (DioClient) |

---

## Future: Dynamic DB-Backed Permissions

Currently permissions are hardcoded in `ROLE_PERMISSIONS` dict in `permissions.py`. The `tenant.user_roles` table stores a JSON `permissions` array per role per company, but this is not read at runtime — the Python dict is used instead.

**Phase 5 plan:** Read permissions from `tenant.user_roles.permissions` JSON at runtime, allowing SUPER_ADMINs to customize role permissions per company without code changes.
