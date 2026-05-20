# Known Issues — Tipper Management ERP

**Version:** 9.0.0
**Last Updated:** 2026-05-19
**Phase:** Enterprise ERP Expansion — Phase 9 Active

---

## Severity Legend

| Level | Meaning |
|---|---|
| 🔴 Critical | Could cause data breach, auth bypass, or production outage |
| 🟠 High | Functional bug or significant risk requiring near-term fix |
| 🟡 Medium | Degraded behaviour or technical debt with workaround |
| 🟢 Low | Code quality / minor improvement |

---

## Authentication Issues

### AUTH-001 — Login uses email-only lookup (cross-tenant risk)
**Severity:** 🔴 Critical  
**File:** `app/api/auth_api.py` — `login()`  
**Description:** The login endpoint queries `User` by email alone with no `company_id` filter. In a multi-tenant system where two companies can have a user with the same email address, this returns the first database match, potentially authenticating the user into the wrong tenant.  
**Fix:** Added optional `company_slug` field to `LoginRequest`. When provided, the backend resolves the company by case-insensitive name match and scopes the user query to `company_id`. Flutter login screen now shows a Company Name field that passes `company_slug` to the API.  
**Status:** ✅ Fixed in Phase 6

---

### AUTH-002 — `/auth/me` uses legacy non-tenant-aware dependency
**Severity:** 🟠 High  
**File:** `app/api/auth_api.py` — `current_user()`  
**Description:** The `/auth/me` endpoint uses `get_current_user` (email-only lookup, no tenant validation), not `get_current_tenant_user`. This means a valid JWT from one company can access `/auth/me` without tenant isolation enforcement.  
**Fix:** Switch `Depends(get_current_user)` to `Depends(get_current_tenant_user)` in `/auth/me`.  
**Status:** 🔧 Identified — Fix in Phase 2

---

### AUTH-003 — Hardcoded weak default SECRET_KEY
**Severity:** 🔴 Critical  
**File:** `app/core/config.py`  
**Description:**
```python
SECRET_KEY = os.getenv("SECRET_KEY", "tipper-secret-key")
```
If `SECRET_KEY` is not set in Railway environment, all JWTs are signed with `"tipper-secret-key"` — a publicly visible default that any attacker can use to forge tokens.  
**Fix:** Add startup warning/guard if SECRET_KEY equals default. Must be set in Railway environment.  
**Status:** 🔧 Identified — Fix in Phase 2 (env-level)

---

### AUTH-004 — Hardcoded default admin password on company registration
**Severity:** 🟠 High  
**File:** `app/api/company_api.py` — `register_company()`  
**Description:**
```python
admin_user = User(
    password_hash=hash_password("admin1234"),
    ...
)
```
Every newly registered company gets an admin user with the hardcoded password `admin1234`. There is no forced password change on first login.  
**Fix:** Either require the registrant to provide an initial password, or force a password-change flow on first login.  
**Status:** 📋 Backlog — Phase 3

---

### AUTH-005 — No logout / token invalidation mechanism
**Severity:** 🟡 Medium  
**Description:** JWT tokens are stateless — once issued they are valid until expiry (default 60 min). There is no token blacklist, no refresh token, and no server-side invalidation. If a token is stolen, it cannot be revoked before expiry.  
**Fix:** Consider token blacklist (Redis) or short expiry + refresh token pattern.  
**Status:** 📋 Backlog — Phase 4

---

### AUTH-006 — `role_id=1` hardcoded in company registration
**Severity:** 🟡 Medium  
**File:** `app/api/company_api.py` — `register_company()`  
**Description:**
```python
admin_user = User(
    role_id=1,  # Assumes auth.roles row with id=1 always exists
    ...
)
```
This assumes that the legacy `auth.roles` Admin row always has `id=1`. If the database is fresh or seeding failed, this foreign key will fail silently or raise an integrity error.  
**Fix:** Look up the Admin role by name rather than hardcoding `id=1`.  
**Status:** 🔧 Identified — Fix in Phase 2

---

## Startup Issues

### START-001 — `ensure_database_schemas()` and `repair_existing_schema()` never called
**Severity:** 🟠 High  
**File:** `app/main.py` — `startup()`  
**Description:** Both `ensure_database_schemas` and `repair_existing_schema` are imported from `app.db.bootstrap` but are not called from the startup event. This means:
- PostgreSQL schemas (`auth`, `master`, `operations`, `tenant`) are NOT explicitly created on startup
- Column repair statements are never executed
- The app relies entirely on `Base.metadata.create_all()` which cannot create schemas
- **On a clean database, startup will fail** because the schemas don't exist before table creation is attempted.  
**Fix:** Call `ensure_database_schemas(engine)` before `Base.metadata.create_all()` in the startup event.  
**Status:** 🔧 Identified — Fix in Phase 2

---

### START-002 — `init_db()` defined but never called
**Severity:** 🟡 Medium  
**File:** `app/db/init_db.py`  
**Description:** The `init_db()` function (which calls `ensure_database_schemas`, `Base.metadata.create_all`, and `repair_existing_schema`) exists but is never imported or called from `main.py`. Dead code.  
**Fix:** Either call `init_db()` from startup, or remove the file and integrate its logic directly.  
**Status:** 🔧 Identified — Fix in Phase 2

---

### START-003 — Seed data runs on every startup
**Severity:** 🟡 Medium  
**File:** `app/db/seed.py` — `seed_data()`  
**Description:** `seed_data()` is called on every startup. It is idempotent (checks `if not existing`) but adds unnecessary DB round-trips on each deploy/restart. Also seeds legacy single-tenant data (`admin@tipper.com` with no `company_id`) which doesn't belong in a multi-tenant context.  
**Fix:** Acceptable for now. Long-term: gate seed_data behind an environment flag.  
**Status:** 📋 Backlog — Low Priority

---

## Database / Session Issues

### DB-001 — Duplicate `get_db()` session factory
**Severity:** 🟢 Low  
**Files:** `app/api/dependencies.py`, `app/api/trip_api.py`, `app/api/dashboard_api.py`, `app/api/vehicle_api.py`, `app/api/driver_api.py`, `app/api/route_api.py`, `app/api/allocation_api.py`, `app/api/trip_expense_api.py`  
**Description:** `get_db()` is defined centrally in `dependencies.py` but also re-defined locally in 7 API files. This creates code duplication — changes to session handling must be made in multiple places.  
**Fix:** Remove local `get_db()` definitions from all API files, import from `dependencies.py`.  
**Status:** ✅ Fixed in Phase 2 (trip_api, dashboard_api) + Phase 3 (vehicle, driver, route, allocation, trip_expense)

---

### DB-002 — Raw `SessionLocal()` usage in API files (inconsistent pattern)
**Severity:** 🟡 Medium  
**Files:** `app/api/auth_api.py`, `app/api/company_api.py`  
**Description:** `auth_api.py` and `company_api.py` create sessions manually with `db = SessionLocal()` inside functions, instead of using the `get_db()` dependency injection pattern. While they do close the session in `finally` blocks, this bypasses FastAPI's dependency injection and makes testing harder.  
**Fix:** Refactor to use `Depends(get_db)` for consistency. Requires careful handling since these routes may not have user auth dependencies.  
**Status:** 📋 Backlog — Phase 3

---

### DB-003 — `company_id` is `nullable=True` on all data models
**Severity:** 🟡 Medium  
**Files:** `models/vehicle.py`, `models/driver.py`, `models/route.py`, `models/trip.py`, `models/trip_expense.py`, `models/assignment.py`  
**Description:** All tenant-scoped models have `company_id = Column(UUID, nullable=True)`. This is a migration artifact — existing rows pre-dating multi-tenancy have no `company_id`. However, all new inserts should have `company_id`. The nullable constraint means there is no database-level enforcement of tenant isolation.  
**Fix:** After validating all existing rows have `company_id` set, consider changing to `nullable=False`. Requires careful migration.  
**Status:** 📋 Backlog — Phase 4

---

## API Structure Issues

### API-001 — Admin dashboard is a dead stub
**Severity:** 🟡 Medium  
**File:** `app/api/admin_api.py`  
**Description:**
```python
@router.get("/dashboard")
def admin_dashboard(current_user=Depends(admin_only)):
    return {"message": "Welcome Admin Dashboard", "user": current_user.full_name}
```
This endpoint is registered and reachable but returns only a mock message. The `admin_only` dependency uses legacy `RoleChecker([1])` (checks `role_id == 1`) — incompatible with multi-tenant RBAC.  
**Fix:** Either build real admin functionality (user management, company listing) or remove the route until it's ready.  
**Status:** 📋 Backlog — Phase 3

---

### API-002 — CORS policy is fully open
**Severity:** 🟠 High  
**File:** `app/main.py`  
**Description:**
```python
allow_origins=["*"]
```
Cross-origin requests are allowed from any domain. In production this means any website can make authenticated API calls on behalf of a logged-in user.  
**Fix:** Restrict `allow_origins` to the actual Flutter web domain (if using web) or specific known origins.  
**Status:** 📋 Backlog — Phase 3

---

### API-003 — No rate limiting on login endpoint
**Severity:** 🟠 High  
**File:** `app/api/auth_api.py` — `POST /auth/login`  
**Description:** The login endpoint has no rate limiting. It is vulnerable to brute-force credential stuffing attacks.  
**Fix:** Add `slowapi` or similar rate limiter middleware, targeting the login endpoint specifically.  
**Status:** 📋 Backlog — Phase 3

---

## Business Logic Issues

### BIZ-001 — Route intelligence fallback is formula-based pseudo-random
**Severity:** 🟡 Medium  
**File:** `app/api/route_intelligence_api.py`  
**Description:** When `GOOGLE_MAPS_API_KEY` is not set, the route intelligence endpoint falls back to a distance estimate derived from a SHA256 hash of the source and destination strings. This produces a deterministic but entirely fictional distance (not real coordinates). Users may not realize the estimate is inaccurate.  
**Fix:** Add a clear `"fallback": true` flag in the response when not using Google Maps.  
**Status:** 📋 Backlog — Phase 3

---

### BIZ-002 — No audit trail (created_by, updated_by)
**Severity:** 🟡 Medium  
**Description:** No models track who created or modified records. There is no `created_by` or `updated_by` field on any entity except implicit timestamp fields on some models.  
**Fix:** Add `created_by_user_id` to operational entities (trips, allocations) as a Phase 3 enhancement.  
**Status:** 📋 Backlog — Phase 4

---

### BIZ-003 — Vehicle `license_number` unique constraint is global, not per-company
**Severity:** 🟡 Medium  
**File:** `models/driver.py`  
**Description:** `license_number = Column(String(100), unique=True)` has a global unique constraint. Two different companies cannot register a driver with the same license number. This will cause failures in production as the platform scales.  
**Fix:** Change to composite unique constraint: `(company_id, license_number)`.  
**Status:** 📋 Backlog — Phase 4

---

### BIZ-004 — Vehicle `vehicle_number` unique constraint is global, not per-company
**Severity:** 🟡 Medium  
**File:** `models/vehicle.py`  
**Description:** `vehicle_number = Column(String(20), unique=True)` is global. Two companies cannot share a vehicle registration number — a real-world constraint that will block registrations as scale increases.  
**Fix:** Change to composite unique: `(company_id, vehicle_number)`.  
**Status:** 📋 Backlog — Phase 4

---

## Phase 3 Issues Added

### TENANT-001 — `_build_list_item()` enrichment queries cross-tenant unscoped
**Severity:** 🟠 High  
**File:** `app/api/trip_api.py` — `_build_list_item()`  
**Description:** Vehicle, Driver, and Route lookups inside `_build_list_item()` used raw `db.query(Model)` with no `filter_by_company()`, allowing enrichment to theoretically pull records from other tenants.  
**Fix:** Added `filter_by_company()` to all three enrichment queries.  
**Status:** ✅ Fixed in Phase 3

---

### TENANT-002 — `_recompute_trip_expense()` and callers lacked company scoping
**Severity:** 🟠 High  
**File:** `app/api/trip_expense_api.py`  
**Description:** `_recompute_trip_expense()` summed TripExpense rows and updated Trip without filtering by `company_id`. `list_expenses()` and `delete_expense()` also lacked `filter_by_company()` on TripExpense queries.  
**Fix:** Refactored function to accept `company_id`, added `filter_by_company()` throughout.  
**Status:** ✅ Fixed in Phase 3

---

### TENANT-003 — `allocation_api._enrich()` enrichment queries unscoped
**Severity:** 🟠 High  
**File:** `app/api/allocation_api.py` — `_enrich()`  
**Description:** Vehicle, Driver, and User lookups in `_enrich()` had no company scoping, risking cross-tenant data leaks in enriched assignment responses.  
**Fix:** Added `filter_by_company()` to vehicle and driver lookups; user lookup scoped via `company_id` filter.  
**Status:** ✅ Fixed in Phase 3

---

### FE-001 — Frontend GET requests missing Authorization header (10 call sites)
**Severity:** 🔴 Critical  
**Files:** `vehicle_service.dart`, `driver_service.dart`, `route_service.dart`, `trip_service.dart`, `allocation_service.dart`, `dashboard_service.dart`, `trip_expense_service.dart`  
**Description:** All GET methods sent requests without a Bearer token. The backend requires `require_permission()` on all these endpoints — every GET would return HTTP 401 in production. `dashboard_service.dart` also had no `_authOptions()` method at all.  
**Fix:** Added `_authOptions()` call to all GET methods. Added TokenStorage import and `_authOptions()` to `DashboardService`.  
**Status:** ✅ Fixed in Phase 3

---

### FE-002 — JWT role_name not decoded or persisted after login
**Severity:** 🟠 High  
**Files:** `auth_service.dart`, `token_storage.dart`  
**Description:** After a successful login, the JWT token was saved but the `role_name` claim was never decoded from the payload. The drawer and screens had no role context.  
**Fix:** Added JWT payload base64-decode in `auth_service.dart` after login. Added `saveRole()`, `getRole()`, `clearRole()`, `clearAll()` to `TokenStorage`. Logout now calls `clearAll()`.  
**Status:** ✅ Fixed in Phase 3

---

### FE-003 — App drawer shows all menu items to all roles (no RBAC)
**Severity:** 🟠 High  
**File:** `core/widgets/app_drawer.dart`  
**Description:** DRIVER users could see and access Vehicles, Drivers, Routes, and Shift Allocation screens — all of which require SUPERVISOR or MANAGER permission. Navigation items were not gated by role.  
**Fix:** Converted `AppDrawer` to `StatefulWidget`, loads role from `TokenStorage` on init. Menu visibility:  
- Dashboard + Trips: ALL roles  
- Shift Allocation: SUPERVISOR, MANAGER, SUPER_ADMIN only  
- Master Data section (Vehicles, Drivers, Routes): MANAGER, SUPER_ADMIN only  
- Role badge added to brand header for clarity.  
**Status:** ✅ Fixed in Phase 3

---

## Phase 4 Issues Added

### ATTEND-001 — Driver self-identification requires user_id link
**Severity:** 🟡 Medium  
**File:** `backend/app/api/attendance_api.py` — `_resolve_driver()`  
**Description:** When a DRIVER user calls `POST /attendance/punch-in` without a body, the backend attempts to find their Driver record via `Driver.user_id == current_user.id`. This only works if a MANAGER has explicitly linked the driver's auth account to their driver profile (via `PUT /drivers/{id}` with `user_id`). Without this link, the DRIVER must supply their own `driver_id` in the request body.  
**Fix:** MANAGER must set `user_id` on each DRIVER's driver profile. This is now a supported field on `PUT /drivers/{id}`.  
**Status:** 🔧 Partial — user_id FK added; link setup is manual  

---

### ATTEND-002 — No duplicate active trip prevention (same vehicle/driver)
**Severity:** 🟡 Medium  
**File:** `backend/app/api/trip_api.py` — `create_trip()`  
**Description:** The system checks vehicle status (must not be ON_TRIP or MAINTENANCE), and auto-fetches driver from active assignment. However, if a vehicle has status ASSIGNED but there's already a CREATED/STARTED trip for it, a duplicate trip could theoretically be created in edge cases where vehicle status was not properly updated.  
**Fix:** Added defensive check querying for any CREATED or STARTED trip on the same `vehicle_id` before creating a new one. Returns 409 if duplicate found.  
**Status:** ✅ Fixed in Phase 6  

---

### FE-004 — 401 interceptor navigation requires navigatorKey to be set
**Severity:** 🟢 Low  
**File:** `lib/core/network/dio_client.dart`, `lib/main.dart`  
**Description:** The 401 interceptor in `DioClient` redirects to `LoginScreen` only if `DioClient.navigatorKey` is set. This is wired in `main.dart`'s `build()` method. Previously each service created its own `Dio()` instance, bypassing the interceptor.  
**Fix:** Migrated all 9 service files (trip, vehicle, driver, route, allocation, attendance, dashboard, trip_expense, route_intelligence) to use `DioClient.instance` and `DioClient.authOptions()`. The 401 interceptor now covers all authenticated calls.  
**Status:** ✅ Fixed in Phase 6  

---

## Phase 5 Issues Added

### ANLT-001 — Analytics N+1 queries on vehicle/driver stats
**Severity:** 🟡 Medium  
**Files:** `backend/app/services/analytics_service.py` — `get_vehicle_trip_stats()`, `get_all_drivers_performance()`  
**Description:** Both functions issued individual trip queries for each vehicle/driver in a loop. For fleets with 50+ vehicles/drivers this produced N+1 DB round-trips.  
**Fix:** Rewrote both functions using SQLAlchemy GROUP BY aggregations. Vehicle stats: 2 queries total regardless of fleet size. Driver stats: 4 queries total (trip counts with `case()`, expense totals, attendance shifts, driver list).  
**Status:** ✅ Fixed in Phase 6

---

### ANLT-002 — Alert detection scans all vehicles/drivers without pagination
**Severity:** 🟡 Medium  
**File:** `backend/app/services/alert_service.py` — `_detect_inactive_vehicles()`, `_detect_inactive_drivers()`  
**Description:** These detectors loaded all AVAILABLE vehicles/drivers into memory and then queried each one individually for recent trips.  
**Fix:** Rewrote both detectors using SQLAlchemy NOT EXISTS correlated subqueries. Single DB round-trip per detector regardless of fleet size.  
**Status:** ✅ Fixed in Phase 6

---

### ANLT-003 — Driver self-stats endpoint requires user_id link
**Severity:** 🟡 Medium  
**File:** `backend/app/api/analytics_api.py` — `GET /analytics/driver/me`  
**Description:** This endpoint resolves the DRIVER's profile via `Driver.user_id == current_user.id`. If the manager has not linked the driver profile to the user account (see ATTEND-001), the endpoint returns HTTP 404.  
**Fix:** Same fix as ATTEND-001 — manager must set `user_id` on each driver profile. Document this dependency clearly in onboarding.  
**Status:** 🔧 Known — same root cause as ATTEND-001

---

### FE-006 — All service files use raw Dio() instead of DioClient.instance
**Severity:** 🟠 High  
**Files:** All 9 service files in `frontend/lib/modules/`  
**Description:** Every service class created its own `Dio()` instance and duplicated `_authOptions()` locally. This meant the shared 401 interceptor in `DioClient` never fired for any service call, so token expiry caused silent 401 errors instead of redirecting the user to login.  
**Fix:** Migrated all services to `DioClient.instance` and `DioClient.authOptions()`. Removed duplicate `_authOptions()` methods. Added `ApiError.extract()` utility at `lib/core/utils/api_error.dart` to replace scattered string-match error parsers with a single, consistent extractor that reads the server's `detail` field.  
**Status:** ✅ Fixed in Phase 6

---

### FE-005 — Dashboard Phase 5 KPI fields default to 0 if old backend
**Severity:** 🟢 Low  
**File:** `frontend/lib/modules/dashboard/models/dashboard_stats_model.dart`  
**Description:** Phase 5 KPI fields (tripsToday, revenueToday, etc.) are Optional with default 0 in the Flutter model. If the backend is an older deployment that doesn't return these fields, the dashboard will silently show 0 for all Phase 5 KPIs rather than showing an error.  
**Fix:** Acceptable. After Railway deployment is updated, all fields will be populated. No action needed.  
**Status:** 📋 Self-resolving on deployment

---

## Phase 6 Issues Added

### PERF-001 — Missing DB indexes on high-frequency query columns
**Severity:** 🟠 High  
**File:** `backend/app/db/bootstrap.py` — `repair_existing_schema()`  
**Description:** All multi-tenant tables lacked indexes on `company_id`, `trip_status`, `trip_date`, and composite columns used in dashboard and analytics queries. With growing data this causes full-table scans on every request.  
**Fix:** Added 15 `CREATE INDEX IF NOT EXISTS` statements in `repair_existing_schema()` covering: per-table company_id, composite (company_id, status), composite (company_id, trip_date), trip_status, trip_date, (driver_id, shift_date), and (vehicle_id, is_active) for assignment lookups.  
**Status:** ✅ Fixed in Phase 6

---

### BIZ-003 — Driver license_number unique constraint is global (not per-company)
**Severity:** 🟠 High  
**File:** `backend/app/db/bootstrap.py`  
**Description:** The `license_number` column had a global UNIQUE constraint, preventing two companies from registering drivers with the same license number (valid across companies in different regions).  
**Fix:** Added `DO $$` block in bootstrap to create `uq_drivers_company_license_number` composite unique constraint on `(company_id, license_number)`, replacing the global unique.  
**Status:** ✅ Fixed in Phase 6

---

### BIZ-004 — Vehicle vehicle_number unique constraint is global (not per-company)
**Severity:** 🟠 High  
**File:** `backend/app/db/bootstrap.py`  
**Description:** Same as BIZ-003 — `vehicle_number` had a global UNIQUE constraint.  
**Fix:** Added `uq_vehicles_company_vehicle_number` composite unique on `(company_id, vehicle_number)`.  
**Status:** ✅ Fixed in Phase 6

---

### LOG-001 — No structured logging — all debug output via print()
**Severity:** 🟡 Medium  
**File:** `backend/app/main.py`, all API files  
**Description:** Backend used `print()` statements. No log levels, no structured format, no stdout routing for Railway log visibility.  
**Fix:** Added `logging.config.dictConfig()` in `main.py` with a console handler (ISO timestamp, level, logger name, message). All `print()` calls in startup replaced with `logger.info()`. Trip lifecycle events (CREATED, STARTED, COMPLETED, CANCELLED) emit structured `logger.info()` lines with vehicle, driver, and company context.  
**Status:** ✅ Fixed in Phase 6

---

### ERR-001 — Unhandled exceptions leak Python stack traces to API consumers
**Severity:** 🟠 High  
**File:** `backend/app/main.py`  
**Description:** Unhandled exceptions in any endpoint returned raw FastAPI 500 responses that could expose internal stack traces, module paths, or sensitive variable names.  
**Fix:** Added `@app.exception_handler(Exception)` global handler that logs the full traceback server-side but returns a clean JSON 500 `{"detail": "An unexpected server error occurred.", "path": "..."}` to the client.  
**Status:** ✅ Fixed in Phase 6

---

## Phase 7 Issues Added

### RBAC-007 — SUPERVISOR missing MANAGE_TRIPS (entire trip lifecycle broken)
**Severity:** 🔴 Critical
**File:** `backend/app/core/permissions.py`
**Description:** SUPERVISOR role had `CREATE_TRIPS` but not `MANAGE_TRIPS`. Since `start_trip`, `complete_trip`, `cancel_trip` (trip_api.py) and `create_assignment`, `release_assignment` (allocation_api.py) all require `MANAGE_TRIPS`, SUPERVISOR could create a trip but could not start, complete, cancel, or even allocate a driver to a vehicle. The entire core ERP operational workflow was broken for the SUPERVISOR role.
**Fix:** Added `Permission.MANAGE_TRIPS` to SUPERVISOR's permission list in `ROLE_PERMISSIONS`.
**Status:** ✅ Fixed in Phase 7

---

### SEC-002 — `/route-intelligence/calculate` has no authentication
**Severity:** 🔴 Critical
**File:** `backend/app/api/route_intelligence_api.py`
**Description:** The route intelligence endpoint had zero auth dependency (`Depends()`). Any unauthenticated caller could POST to `/route-intelligence/calculate` without a token and consume the backend's Google Maps API quota. Also bypasses tenant isolation entirely.
**Fix:** Added `Depends(require_permission(Permission.CREATE_TRIPS))` to `calculate_route()` — requires SUPERVISOR or above.
**Status:** ✅ Fixed in Phase 7

---

### TENANT-004 — `company_api.py` registration leaks raw exception detail
**Severity:** 🟠 High
**File:** `backend/app/api/company_api.py` — `register_company()`
**Description:** The except block raised `HTTPException(detail=f"Registration failed: {exc}")`, leaking raw Python exception strings (including internal paths, SQL errors, and model names) to the API consumer.
**Fix:** Exception is now logged server-side via `logger.error(..., exc_info=True)` and a generic `"Company registration failed due to a server error. Please try again."` message is returned to the client.
**Status:** ✅ Fixed in Phase 7

---

### DB-004 — `company_id` column missing on pre-existing tables
**Severity:** 🔴 Critical
**File:** `backend/app/db/bootstrap.py` — `repair_existing_schema()`
**Description:** On Railway, `repair_existing_schema()` failed with `ProgrammingError: column "company_id" does not exist` when trying to create the performance indexes. Root cause: `Base.metadata.create_all()` skips tables that already exist, so `company_id` (added to SQLAlchemy models later) was never added to older database tables. The index creation then tried to index a non-existent column.
**Fix:** Added 7 `ALTER TABLE ... ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES tenant.companies(id) ON DELETE CASCADE` statements to `repair_existing_schema()`, placed before all `CREATE INDEX` statements. Fully idempotent.
**Status:** ✅ Fixed in Phase 7

---

### DASH-001 — Dashboard makes 21+ separate DB queries per request
**Severity:** 🟡 Medium
**File:** `backend/app/api/dashboard_api.py` — `get_dashboard_stats()`
**Description:** The dashboard stats endpoint issued approximately 21 separate `filter_by_company()` + `.scalar()` queries for vehicle counts (5), driver counts (3), route count (1), attendance (1), trip lifecycle counts (5), financial sums (3), plus 3 analytics service calls. While each query was fast with indexes, this was architecturally wasteful and would show latency at scale.
**Fix:** Consolidated into 7 GROUP BY aggregation queries using SQLAlchemy `case()` + `func.sum()` for vehicle status, driver status, trip status counts, financials, Phase 5 KPIs (today/month), attendance today, and route count. Vehicle, driver, and trip status counts each use one query.
**Status:** ✅ Fixed in Phase 9 (DASH-001)

---

## Phase 9 Issues Added

### GAP-005 — Subscription limits not enforced
**Severity:** 🟡 Medium
**File:** `backend/app/api/company_api.py`, `backend/app/models/company.py` — `CompanySettings`
**Description:** `CompanySettings` stores `max_users`, `max_vehicles`, and `subscription_tier` per company, but these limits are never checked during vehicle/driver/user creation. A BASIC tier company can add unlimited vehicles.
**Fix:** Add limit enforcement in vehicle/driver create endpoints — query count before insert, raise 403/402 if exceeded.
**Status:** 📋 Backlog — Phase 10

---

### GAP-006 — No user invitation or management API
**Severity:** 🟡 Medium
**File:** (missing) `backend/app/api/user_api.py`
**Description:** `MANAGE_USERS` and `VIEW_USERS` permissions exist in the RBAC system, but there is no `/users/` API endpoint. Company admins cannot add employees, change roles, or reset passwords via the API.
**Fix:** Build `user_api.py` with CRUD: invite user (create with role), list users, update role, deactivate user.
**Status:** 📋 Backlog — Phase 10

---

### AUTH-004 — Hardcoded default admin password on company registration
**Severity:** 🟠 High
**File:** `backend/app/api/company_api.py` — `register_company()`
**Description:** Every newly registered company gets an admin user with the hardcoded password `admin1234`. There is no forced password change on first login.
**Fix:** Either require the registrant to provide an initial password, or force a password-change flow on first login.
**Status:** 📋 Backlog — Phase 10 (AUTH-004)

---

### DOC-001 — Document file upload not yet supported (metadata-only)
**Severity:** 🟢 Low
**File:** `backend/app/api/document_api.py`, `backend/app/models/document.py`
**Description:** The Document Management module stores metadata only. The `file_path` column exists as a VARCHAR placeholder for future S3/GCS integration. Actual file upload, storage, and retrieval are not implemented.
**Fix:** Integrate with AWS S3 or Google Cloud Storage. Add file upload endpoint with pre-signed URL generation.
**Status:** 📋 Backlog — Phase 11

---

## Phase 2 + Phase 3 Fix Tracker

| Issue ID | Description | Priority | Status |
|---|---|---|---|
| AUTH-001 | Login email-only lookup | 🔴 Critical | 📋 Phase 4 |
| AUTH-002 | `/auth/me` uses legacy dependency | 🟠 High | ✅ Fixed in Phase 2 |
| AUTH-003 | Weak default SECRET_KEY | 🔴 Critical | 🔧 Env-level (must set in Railway) |
| AUTH-006 | `role_id=1` hardcoded | 🟡 Medium | ✅ Fixed in Phase 2 |
| START-001 | Bootstrap functions not called | 🟠 High | ✅ Fixed in Phase 2 |
| START-002 | `init_db()` never called | 🟡 Medium | ✅ Fixed in Phase 2 |
| DB-001 | Duplicate `get_db()` in 7 API files | 🟢 Low | ✅ Fixed in Phase 2+3 |
| TENANT-001 | Trip `_build_list_item()` unscoped enrichment | 🟠 High | ✅ Fixed in Phase 3 |
| TENANT-002 | Trip expense queries and recompute unscoped | 🟠 High | ✅ Fixed in Phase 3 |
| TENANT-003 | Allocation `_enrich()` unscoped | 🟠 High | ✅ Fixed in Phase 3 |
| FE-001 | Frontend GET requests missing auth token | 🔴 Critical | ✅ Fixed in Phase 3 |
| FE-002 | JWT role not decoded or persisted | 🟠 High | ✅ Fixed in Phase 3 |
| FE-003 | App drawer shows all menus regardless of role | 🟠 High | ✅ Fixed in Phase 3 |
| ATTEND-001 | Driver user_id link required for self-attendance | 🟡 Medium | 🔧 Partial Phase 4 |
| FE-004 | 401 interceptor — services use local Dio, not shared | 🟢 Low | 📋 Phase 5 |
| P4-TRIPS | DRIVER sees all company trips, not own only | 🟠 High | ✅ Fixed in Phase 4 |
| P4-ATTEND | No attendance module in codebase | 🔴 Critical | ✅ Added in Phase 4 |
| ANLT-001 | Analytics N+1 queries on vehicle/driver stats | 🟡 Medium | ✅ Fixed in Phase 6 (GROUP BY) |
| ANLT-002 | Alert detection scans all vehicles/drivers in memory | 🟡 Medium | ✅ Fixed in Phase 6 (NOT EXISTS) |
| ANLT-003 | Driver self-stats requires user_id link | 🟡 Medium | 🔧 Same as ATTEND-001 |
| FE-005 | Phase 5 KPI fields default to 0 on old backend | 🟢 Low | 📋 Self-resolving on deploy |
| AUTH-001 | Login email-only lookup (cross-tenant risk) | 🔴 Critical | ✅ Fixed in Phase 6 (company_slug) |
| ATTEND-002 | No duplicate active trip prevention | 🟡 Medium | ✅ Fixed in Phase 6 |
| FE-004 | Services use local Dio() — 401 interceptor bypassed | 🟠 High | ✅ Fixed in Phase 6 |
| FE-006 | Scattered string-match error parsers | 🟡 Medium | ✅ Fixed in Phase 6 (ApiError.extract) |
| PERF-001 | Missing DB indexes on company_id / trip_status / trip_date | 🟠 High | ✅ Fixed in Phase 6 |
| BIZ-003 | license_number unique constraint is global not per-company | 🟠 High | ✅ Fixed in Phase 6 |
| BIZ-004 | vehicle_number unique constraint is global not per-company | 🟠 High | ✅ Fixed in Phase 6 |
| LOG-001 | No structured logging — print() only | 🟡 Medium | ✅ Fixed in Phase 6 |
| ERR-001 | Stack traces leak in 500 responses | 🟠 High | ✅ Fixed in Phase 6 |
| RBAC-007 | SUPERVISOR missing MANAGE_TRIPS — can't start/complete/cancel/allocate | 🔴 Critical | ✅ Fixed in Phase 7 |
| SEC-002 | /route-intelligence/calculate has no auth — API key exposed | 🔴 Critical | ✅ Fixed in Phase 7 |
| TENANT-004 | company_api registration leaks raw Python exception to client | 🟠 High | ✅ Fixed in Phase 7 |
| DEPLOY-001 | DEPLOYMENT_FLOW.md stale — showed old /docs healthcheck and blocking startup | 🟡 Medium | ✅ Fixed in Phase 7 |
| DB-004 | company_id column missing on pre-existing tables — repair_existing_schema fails | 🔴 Critical | ✅ Fixed in Phase 7 (ALTER TABLE backfill before CREATE INDEX) |
| DASH-001 | Dashboard makes 21+ separate DB queries per request | 🟡 Medium | ✅ Fixed in Phase 9 (7 GROUP BY aggregations) |
| GAP-005 | Subscription limits not enforced (max_vehicles, max_users ignored) | 🟡 Medium | 📋 Backlog — Phase 10 |
| GAP-006 | No user management API (MANAGE_USERS permission exists, no endpoint) | 🟡 Medium | 📋 Backlog — Phase 10 |
| AUTH-004 | Default admin1234 password on registration — no forced change | 🟠 High | 📋 Backlog — Phase 10 |
| DOC-001 | Document file upload not yet supported — metadata-only | 🟢 Low | 📋 Backlog — Phase 11 (S3/GCS) |
