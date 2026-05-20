# Known Issues — Tipper Management ERP

**Version:** 10.0.0
**Last Updated:** 2026-05-20
**Phase:** Phase 10 — Production SaaS Maturity + Automation

---

## Severity Legend

| Level | Meaning |
|---|---|
| 🔴 Critical | Could cause data breach, auth bypass, or production outage |
| 🟠 High | Functional bug or significant risk requiring near-term fix |
| 🟡 Medium | Degraded behaviour or technical debt with workaround |
| 🟢 Low | Code quality / minor improvement |

---

## Phase 10 Issues Added

### SEC-003 — CORS was fully open (allow_origins=["*"])
**Severity:** 🟠 High
**File:** `backend/app/main.py`
**Description:** CORS allowed requests from any origin in production.
**Fix:** Restricted to `ALLOWED_ORIGINS` env var (defaults to Railway frontend URL). Methods and headers also locked down.
**Status:** ✅ Fixed in Phase 10

---

### FE-007 — dart:html top-level import breaks iOS/Android compilation
**Severity:** 🔴 Critical
**File:** `frontend/lib/core/storage/token_storage.dart`
**Description:** `import 'dart:html'` at the top level caused compile failure on native targets. Runtime `kIsWeb` check does not prevent compile-time import resolution.
**Fix:** Refactored using Flutter conditional imports (`if (dart.library.html)`). Three files: `storage_interface.dart`, `storage_web.dart`, `storage_native.dart`.
**Status:** ✅ Fixed in Phase 10

---

### GAP-006 — No user management API
**Severity:** 🟡 Medium
**File:** `backend/app/api/user_api.py` (new)
**Description:** `MANAGE_USERS` permission existed but no `/users/` endpoint. Admins couldn't add staff.
**Fix:** Built full CRUD at `/users/` — list, create, get, update, deactivate. Tenant-isolated, RBAC-gated.
**Status:** ✅ Fixed in Phase 10

---

### GAP-007 — No document expiry or maintenance overdue alerts
**Severity:** 🟠 High
**File:** `backend/app/services/alert_service.py`
**Description:** Phase 9 added document and maintenance modules but no alert detectors for expiry/overdue.
**Fix:** Added `_detect_document_expiry()` (CRITICAL if expired, HIGH if within 30 days) and `_detect_maintenance_overdue()` (HIGH if >3 days overdue).
**Status:** ✅ Fixed in Phase 10

---

### GAP-008 — No frontend screens for Phase 9 modules
**Severity:** 🟠 High
**Files:** `frontend/lib/modules/maintenance/`, `fuel/`, `document/`
**Description:** Maintenance, Fuel, and Document APIs existed in backend but had no Flutter UI.
**Fix:** Built full screens and services for all 3 modules. Added Enterprise section to app drawer (MANAGER+ only).
**Status:** ✅ Fixed in Phase 10

---

### GAP-009 — No operational automation (stuck vehicles/drivers)
**Severity:** 🟠 High
**File:** `backend/app/services/automation_service.py` (new)
**Description:** Vehicles/drivers could get stuck in ON_TRIP status after trip completion due to partial failures. No background correction.
**Fix:** Background scheduler runs every 5 minutes — frees stuck vehicles/drivers, logs overdue trips. `GET /automation/status` for observability.
**Status:** ✅ Fixed in Phase 10

---

## Open / Backlog Issues

### AUTH-003 — Hardcoded weak default SECRET_KEY
**Severity:** 🔴 Critical
**Status:** 🔧 Must set `SECRET_KEY` in Railway environment variables

### AUTH-004 — Default admin1234 password on registration
**Severity:** 🟠 High
**Status:** 📋 Backlog — Phase 11

### GAP-005 — Subscription limits not enforced
**Severity:** 🟡 Medium
**Status:** 📋 Backlog — Phase 11

### DOC-001 — Document file upload (metadata-only, no S3)
**Severity:** 🟢 Low
**Status:** 📋 Backlog — Phase 11

### API-003 — No rate limiting on login endpoint
**Severity:** 🟠 High
**Status:** 📋 Backlog — Phase 11

---

## Historical Fix Tracker

| Issue | Description | Status |
|---|---|---|
| AUTH-001 | Login email-only lookup | ✅ Fixed Phase 6 |
| AUTH-002 | /auth/me legacy dependency | ✅ Fixed Phase 2 |
| AUTH-006 | role_id=1 hardcoded | ✅ Fixed Phase 2 |
| START-001 | Bootstrap not called | ✅ Fixed Phase 2 |
| DB-001 | Duplicate get_db() | ✅ Fixed Phase 2+3 |
| TENANT-001..003 | Unscoped enrichment queries | ✅ Fixed Phase 3 |
| FE-001..003 | Auth headers, role decode, drawer RBAC | ✅ Fixed Phase 3 |
| ANLT-001..002 | N+1 queries, memory scans | ✅ Fixed Phase 6 |
| PERF-001 | Missing DB indexes | ✅ Fixed Phase 6 |
| BIZ-003..004 | Global unique constraints | ✅ Fixed Phase 6 |
| LOG-001 | No structured logging | ✅ Fixed Phase 6 |
| ERR-001 | Stack trace leaks | ✅ Fixed Phase 6 |
| RBAC-007 | SUPERVISOR missing MANAGE_TRIPS | ✅ Fixed Phase 7 |
| SEC-002 | Route intelligence no auth | ✅ Fixed Phase 7 |
| DB-004 | company_id missing on old tables | ✅ Fixed Phase 7 |
| DASH-001 | 21+ queries per dashboard request | ✅ Fixed Phase 9 |
| SEC-003 | CORS wildcard | ✅ Fixed Phase 10 |
| FE-007 | dart:html breaks native builds | ✅ Fixed Phase 10 |
| GAP-006 | No user management API | ✅ Fixed Phase 10 |
| GAP-007 | No doc expiry / maintenance alerts | ✅ Fixed Phase 10 |
| GAP-008 | No frontend Phase 9 screens | ✅ Fixed Phase 10 |
| GAP-009 | No operational automation | ✅ Fixed Phase 10 |
