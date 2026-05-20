# Module Status — Tipper Management ERP

**Version:** 9.0.0
**Last Updated:** 2026-05-19
**Phase:** Enterprise ERP Expansion — Phase 9 Active

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
| Permissions | `app/core/permissions.py` | ✅ Working | Clean enum-based RBAC. Phase 7 (RBAC-007): MANAGE_TRIPS added to SUPERVISOR. Phase 9: 7 new permissions added (MANAGE_MAINTENANCE, VIEW_MAINTENANCE, MANAGE_FUEL, VIEW_FUEL, MANAGE_DOCUMENTS, VIEW_DOCUMENTS, VIEW_REPORTS). |
| DB Session | `app/db/session.py` | ✅ Working | pool_pre_ping=True, autoflush=False |
| Bootstrap | `app/db/bootstrap.py` | ✅ Working | Called from startup. Phase 6 adds 15 performance indexes + per-company unique constraints (BIZ-003, BIZ-004). |
| DB Init | `app/db/init_db.py` | ⚠️ Partial | `init_db()` defined but **never called** from `main.py` |
| Seed Data | `app/db/seed.py` | ⚠️ Partial | Runs on every startup. Idempotent for roles/admin user. Seeds legacy single-tenant data only (no company_id). |
| Tenant Queries | `app/db/tenant_queries.py` | ✅ Working | `filter_by_company()` correctly filters by TenantContext company_id |

### API Routers

| Module | File | Status | Notes |
|---|---|---|---|
| Authentication | `app/api/auth_api.py` | ⚠️ Partial | Login works. Phase 6: optional `company_slug` scopes login to tenant (AUTH-001 fixed). `/auth/me` still uses legacy `get_current_user` (email-only). |
| Company Management | `app/api/company_api.py` | ✅ Working | Registration, duplicate check, default roles/settings, admin user creation all functional. Phase 7: exception detail no longer leaked to client (TENANT-004). |
| Vehicle Master | `app/api/vehicle_api.py` | ✅ Working | Full CRUD with tenant isolation and permission checks |
| Driver Master | `app/api/driver_api.py` | ✅ Working | Full CRUD with tenant isolation and permission checks |
| Route Master | `app/api/route_api.py` | ✅ Working | Full CRUD with tenant isolation and permission checks |
| Shift Allocation | `app/api/allocation_api.py` | ✅ Working | Create, list, release assignments with vehicle/driver status sync |
| Route Intelligence | `app/api/route_intelligence_api.py` | ✅ Working | Phase 7 (SEC-002): endpoint now requires auth (CREATE_TRIPS permission). Google Maps when key present, formula fallback otherwise. Response includes `source` field to distinguish. |
| Trip Operations | `app/api/trip_api.py` | ✅ Working | Full lifecycle: CREATE → START → COMPLETE/CANCEL. FSM enforced. Phase 6: duplicate active trip check (ATTEND-002), structured logging for all lifecycle events. |
| Trip Expenses | `app/api/trip_expense_api.py` | ✅ Working | Add/list/delete expenses per trip with tenant isolation |
| Dashboard Analytics | `app/api/dashboard_api.py` | ✅ Working | Phase 9 (DASH-001 fixed): consolidated from 21+ scalar queries to 7 GROUP BY aggregations. Vehicle/driver/trip status counts each use one query. All counters, financials, utilisation %, Phase 5 KPIs. Company-scoped. |
| Analytics API | `app/api/analytics_api.py` | ✅ Working | Phase 5: /analytics/operational, /driver/me, /fleet, /alerts, /supervisor/snapshot |
| Maintenance Management | `app/api/maintenance_api.py` | ✅ Working | Phase 9: Full CRUD. Tenant-isolated, vehicle-linked. Status FSM: SCHEDULED→IN_PROGRESS→COMPLETED. By-vehicle listing. |
| Fuel Management | `app/api/fuel_api.py` | ✅ Working | Phase 9: Full CRUD + analytics. Trip-linked, bulk-enriched vehicle/driver names. Analytics endpoint (totals, avg cost/litre). |
| Document Management | `app/api/document_api.py` | ✅ Working | Phase 9: Metadata-only CRUD. Expiry tracking (is_expired, days_to_expiry computed server-side). /expiring?days=N endpoint. |
| Reports & Export | `app/api/reports_api.py` | ✅ Working | Phase 9: CSV export for trips, expenses, fuel, maintenance, attendance. StreamingResponse — no memory buffering. |
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
| Analytics Service | `services/analytics_service.py` | ✅ Working | Pure functions: trip counts/financials, fleet utilization, driver performance, attendance, supervisor snapshot. Phase 6: GROUP BY aggregations replace N+1 loops (ANLT-001). |
| Alert Service | `services/alert_service.py` | ✅ Working | Stateless detectors: overdue trips, excessive expenses, low attendance, inactive vehicles/drivers, high cancellations. Phase 6: NOT EXISTS subqueries replace per-entity scans (ANLT-002). |

### Schemas (Pydantic)

| Schema File | Status | Notes |
|---|---|---|
| `schemas/auth_schema.py` | ✅ Working | LoginRequest (Phase 6: added optional `company_slug`), TokenResponse |
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
| HTTP Client (Dio) | ✅ Working | Phase 6: all 9 services migrated to `DioClient.instance`. 401 interceptor now covers all authenticated calls. |
| Secure Token Storage | ✅ Working | flutter_secure_storage ^10.1.0 |
| State Management | ✅ Working | Provider ^6.1.5+1 |
| Navigation | ✅ Working | go_router ^17.2.3 |
| Platform Support | ✅ Working | iOS, Android, macOS, Windows, Linux, Web |
| Error Handling Utility | ✅ Working | Phase 6: `lib/core/utils/api_error.dart` — `ApiError.extract()` reads server `detail` field, with HTTP status and network error fallbacks. Used by trip, attendance, and create screens. |
| Login Screen | ✅ Working | Phase 6: added Company Name field; passes `company_slug` to backend for tenant-scoped login (AUTH-001). |

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
| API Routers | 17 | 15 | 1 | 0 | 1 |
| Models | 15 | 13 | 1 | 0 | 1 |
| Core Modules | 9 | 7 | 1 | 0 | 1 |
| Schemas | 14 | 14 | 0 | 0 | 0 |
| Services | 2 | 2 | 0 | 0 | 0 |

**Phase 9 changes:** +4 new API routers (maintenance, fuel, documents, reports), +3 new models, +3 new schemas. Dashboard DASH-001 fixed (21+ → 7 GROUP BY queries). +7 new RBAC permissions.
