# Module Status — Tipper Management ERP

**Version:** 4.0.0  
**Last Updated:** 2026-05-19  
**Phase:** Analytics + Dashboard Intelligence + AI Foundation — Phase 5 Complete  

---

## Status Legend

| Symbol | Meaning |
|---|---|
| ✅ Working | Fully functional, production-safe |
| ⚠️ Partial | Works but has known gaps or risks |
| ❌ Broken | Not functional or unsafe |
| 🔒 Legacy | Old code kept for compatibility, not recommended |

---

## Backend Modules

### Core Infrastructure

| Module | File | Status | Notes |
|---|---|---|---|
| Config | `app/core/config.py` | ✅ Working | DATABASE_URL guard in place. Weak default SECRET_KEY. |
| Security (JWT + bcrypt) | `app/core/security.py` | ✅ Working | hash_password, verify_password, create_access_token all functional |
| Tenant Context | `app/core/tenant.py` | ✅ Working | contextvars-based, async-safe per-request isolation |
| Permissions | `app/core/permissions.py` | ✅ Working | Clean enum-based RBAC with ROLE_PERMISSIONS dict |
| DB Session | `app/db/session.py` | ✅ Working | pool_pre_ping=True, autoflush=False |
| Bootstrap | `app/db/bootstrap.py` | ⚠️ Partial | Functions defined but **NOT called from startup**. Schema creation and column repairs are skipped at runtime. |
| DB Init | `app/db/init_db.py` | ⚠️ Partial | `init_db()` defined but **never called** from `main.py` |
| Seed Data | `app/db/seed.py` | ⚠️ Partial | Runs on every startup. Idempotent for roles/admin user. Seeds legacy single-tenant data only (no company_id). |
| Tenant Queries | `app/db/tenant_queries.py` | ✅ Working | `filter_by_company()` correctly filters by TenantContext company_id |

### API Routers

| Module | File | Status | Notes |
|---|---|---|---|
| Authentication | `app/api/auth_api.py` | ⚠️ Partial | Login works. `/auth/me` uses legacy `get_current_user` (email-only, no tenant isolation). Login does email-only lookup (no company_id filter). |
| Company Management | `app/api/company_api.py` | ✅ Working | Registration, duplicate check, default roles/settings, admin user creation all functional |
| Vehicle Master | `app/api/vehicle_api.py` | ✅ Working | Full CRUD with tenant isolation and permission checks |
| Driver Master | `app/api/driver_api.py` | ✅ Working | Full CRUD with tenant isolation and permission checks |
| Route Master | `app/api/route_api.py` | ✅ Working | Full CRUD with tenant isolation and permission checks |
| Shift Allocation | `app/api/allocation_api.py` | ✅ Working | Create, list, release assignments with vehicle/driver status sync |
| Route Intelligence | `app/api/route_intelligence_api.py` | ⚠️ Partial | Google Maps integration works when key present. Fallback formula uses pseudo-random (SHA256 seed) — not real coordinates. |
| Trip Operations | `app/api/trip_api.py` | ✅ Working | Full lifecycle: CREATE → START → COMPLETE/CANCEL. FSM enforced (status transition checks). Status syncs to vehicle/driver. |
| Trip Expenses | `app/api/trip_expense_api.py` | ✅ Working | Add/list/delete expenses per trip with tenant isolation |
| Dashboard Analytics | `app/api/dashboard_api.py` | ✅ Working | All counters, financials, utilisation %, plus Phase 5 today/month KPIs. Company-scoped. |
| Analytics API | `app/api/analytics_api.py` | ✅ Working | Phase 5: /analytics/operational, /driver/me, /fleet, /alerts, /supervisor/snapshot |
| Admin Dashboard | `app/api/admin_api.py` | ❌ Broken | Stub endpoint — returns mock message only. Uses legacy `RoleChecker` (role_id=1 check, not RBAC). No real admin functionality. |
| Dependencies | `app/api/dependencies.py` | ⚠️ Partial | `get_current_tenant_user` is correct. `get_current_user` (legacy, email-only) still exposed and used by `/auth/me` and admin_api. |
| Role Checker | `app/api/role_checker.py` | 🔒 Legacy | `RoleChecker` class uses legacy `role_id` check. Should not be extended. |

### Models

| Model | File | Schema | Status | Notes |
|---|---|---|---|---|
| Role | `models/role.py` | auth | 🔒 Legacy | Legacy single-tenant roles. Still seeded on startup. |
| User | `models/user.py` | auth | ⚠️ Partial | Has both legacy `role_id` and multi-tenant `company_id` + `user_role_id`. Hybrid state. |
| Company | `models/company.py` | tenant | ✅ Working | Core tenant entity with all relationships |
| CompanySettings | `models/company.py` | tenant | ✅ Working | Per-company limits and subscription tier |
| UserRole | `models/company.py` | tenant | ✅ Working | Per-company RBAC roles with JSON permissions |
| Vehicle | `models/vehicle.py` | master | ✅ Working | Status constants defined. company_id nullable (migration artifact). |
| Driver | `models/driver.py` | master | ✅ Working | Status constants defined. company_id nullable (migration artifact). |
| Route | `models/route.py` | master | ✅ Working | company_id nullable (migration artifact). |
| DriverVehicleAssignment | `models/assignment.py` | master | ✅ Working | Shift assignment with is_active flag |
| Trip | `models/trip.py` | operations | ✅ Working | Full lifecycle fields, company_id nullable (migration artifact) |
| TripExpense | `models/trip_expense.py` | operations | ✅ Working | Itemized expenses per trip |
| DriverAttendance | `models/attendance.py` | operations | ✅ Working | Phase 4: punch_in/out, is_active, UniqueConstraint(driver_id, shift_date, company_id) |

### Services (Phase 5 — Analytics Layer)

| Service | File | Status | Notes |
|---|---|---|---|
| Analytics Service | `services/analytics_service.py` | ✅ Working | Pure functions: trip counts/financials, fleet utilization, driver performance, attendance, supervisor snapshot |
| Alert Service | `services/alert_service.py` | ✅ Working | Stateless detectors: overdue trips, excessive expenses, low attendance, inactive vehicles/drivers, high cancellations |

### Schemas (Pydantic)

| Schema File | Status | Notes |
|---|---|---|
| `schemas/auth_schema.py` | ✅ Working | LoginRequest, TokenResponse |
| `schemas/company_schema.py` | ✅ Working | Register, Response, Detail |
| `schemas/vehicle_schema.py` | ✅ Working | CRUD schemas |
| `schemas/driver_schema.py` | ✅ Working | CRUD schemas |
| `schemas/route_schema.py` | ✅ Working | CRUD schemas |
| `schemas/assignment_schema.py` | ✅ Working | Allocation schemas |
| `schemas/trip_schema.py` | ✅ Working | Create, Response, ListItem, Start/Complete/Cancel requests |
| `schemas/trip_expense_schema.py` | ✅ Working | Expense schemas |
| `schemas/dashboard_schema.py` | ✅ Working | DashboardStats schema — Phase 5 adds today/month KPI fields (Optional, backward-compatible) |
| `schemas/analytics_schema.py` | ✅ Working | Phase 5: TimeWindow, OperationalKPIs, FleetAnalytics, DriverPerformance, DriverSelfStats, SupervisorSnapshot, OperationalAlert, AlertsResponse |

---

## Frontend Modules

| Module | Status | Notes |
|---|---|---|
| HTTP Client (Dio) | ✅ Working | dio ^5.9.2 configured |
| Secure Token Storage | ✅ Working | flutter_secure_storage ^10.1.0 |
| State Management | ✅ Working | Provider ^6.1.5+1 |
| Navigation | ✅ Working | go_router ^17.2.3 |
| Platform Support | ✅ Working | iOS, Android, macOS, Windows, Linux, Web |

> **Note:** Full Flutter lib/ structure not audited in this phase. Frontend internals to be documented in Phase 3.

---

## Alembic Migrations

| Migration ID | Date | Status | Notes |
|---|---|---|---|
| `6c49d61bb804` | 2026-05-09 | ✅ Applied | Initial schema — all tables |
| `ee2c2b6b204c` | After initial | ✅ Applied | Updates routes table |
| `64e866bd0f40` | After routes | ✅ Applied | Adds remarks to routes |
| `a1b2c3d4e5f6` | 2026-05-11 | ✅ Applied | Major: adds tenant schema + company_id columns to all tables |

---

## Summary Dashboard

| Category | Total | ✅ Working | ⚠️ Partial | ❌ Broken | 🔒 Legacy |
|---|---|---|---|---|---|
| API Routers | 13 | 9 | 2 | 1 | 1 |
| Models | 12 | 10 | 1 | 0 | 1 |
| Core Modules | 8 | 4 | 3 | 0 | 1 |
| Schemas | 11 | 11 | 0 | 0 | 0 |
| Services | 2 | 2 | 0 | 0 | 0 |
