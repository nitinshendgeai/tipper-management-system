# Known Issues — Tipper Management ERP

**Version:** 2.1.0  
**Last Updated:** 2026-05-18  
**Phase:** System Stabilization — Phase 3 RBAC + Multi-Tenant  

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
**The code even documents this limitation:**
```python
# For multi-tenant users, email is scoped per company so we look up
# by email alone (the first match). In a fully tenant-aware login the
# client would also supply company_id; for now we match on email.
```
**Fix:** Login request must include `company_id` (or a company slug) and the DB query must filter `WHERE email=? AND company_id=?`.  
**Status:** 🔧 Identified — Fix in Phase 2

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
