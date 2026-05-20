# Known Issues — Tipper Management ERP

**Version:** 11.0.0
**Last Updated:** 2026-05-20
**Phase:** Phase 11 — Security Hardening + SaaS Maturity

---

## Severity Legend

| Level | Meaning |
|---|---|
| 🔴 Critical | Data breach, auth bypass, or production outage |
| 🟠 High | Functional bug or significant risk |
| 🟡 Medium | Degraded behaviour with workaround |
| 🟢 Low | Code quality / minor improvement |

---

## Phase 11 Issues Fixed

### AUTH-004 — Hardcoded admin1234 password
**Severity:** 🟠 High → ✅ Fixed
**Fix:** Registration now generates a cryptographically secure random password (or accepts caller-supplied password). Returned once in response. `must_change_password=True` set on account — forced change screen shown on first login.

### GAP-005 — Subscription limits not enforced
**Severity:** 🟡 Medium → ✅ Fixed
**Fix:** Vehicle create checks `max_vehicles`, driver/user create checks `max_users` against `CompanySettings`. Returns HTTP 403 with upgrade message if limit exceeded.

### API-003 — No rate limiting on login
**Severity:** 🟠 High → ✅ Fixed
**Fix:** In-memory rate limiter — 10 attempts per IP per 60 seconds. Returns HTTP 429. No external dependency required.

### GAP-008 — No User Management Flutter screen
**Severity:** 🟠 High → ✅ Fixed
**Fix:** Full `UserScreen` built — list, add, edit, deactivate. Added to drawer under Enterprise section (MANAGER+ only).

---

## Open / Backlog Issues

### AUTH-003 — Weak default SECRET_KEY
**Severity:** 🔴 Critical
**Description:** If `SECRET_KEY` not set in Railway env, defaults to `tipper-secret-key`.
**Fix:** Set `SECRET_KEY` in Railway environment variables immediately.
**Status:** 🔧 Must fix manually in Railway dashboard

### DOC-001 — Document file upload not supported
**Severity:** 🟢 Low
**Description:** Documents module stores metadata only. No file upload/storage.
**Fix:** Integrate AWS S3 or GCS in Phase 12.
**Status:** 📋 Backlog — Phase 12

### AUTH-005 — No token invalidation on logout
**Severity:** 🟡 Medium
**Description:** JWTs are stateless — stolen tokens valid until expiry (60 min).
**Fix:** Add token blacklist (Redis) or short expiry + refresh token pattern.
**Status:** 📋 Backlog — Phase 12

### DB-003 — company_id nullable on all models
**Severity:** 🟡 Medium
**Description:** All tenant-scoped models have `company_id = nullable=True` as migration artifact.
**Fix:** After validating all rows, change to `nullable=False`.
**Status:** 📋 Backlog — Phase 12

### RATE-001 — Rate limiter is in-memory (resets on restart)
**Severity:** 🟡 Medium
**Description:** Login rate limiter uses Python dict — resets on every Railway deploy/restart. Brute force across restarts is possible.
**Fix:** Use Redis for persistent rate limiting in Phase 12.
**Status:** 📋 Backlog — Phase 12

---

## Full Fix History

| Issue | Description | Fixed |
|---|---|---|
| AUTH-001 | Login email-only lookup | Phase 6 |
| AUTH-002 | /auth/me legacy dependency | Phase 2 |
| AUTH-004 | Hardcoded admin1234 password | Phase 11 |
| AUTH-006 | role_id=1 hardcoded | Phase 2 |
| START-001 | Bootstrap not called on startup | Phase 2 |
| DB-001 | Duplicate get_db() in API files | Phase 2+3 |
| TENANT-001..003 | Unscoped enrichment queries | Phase 3 |
| FE-001..003 | Auth headers, role decode, drawer RBAC | Phase 3 |
| ANLT-001..002 | N+1 queries, memory alert scans | Phase 6 |
| PERF-001 | Missing DB indexes | Phase 6 |
| BIZ-003..004 | Global unique constraints | Phase 6 |
| LOG-001 | No structured logging | Phase 6 |
| ERR-001 | Stack trace leaks in 500 responses | Phase 6 |
| RBAC-007 | SUPERVISOR missing MANAGE_TRIPS | Phase 7 |
| SEC-002 | Route intelligence no auth | Phase 7 |
| DB-004 | company_id missing on pre-existing tables | Phase 7 |
| DASH-001 | 21+ DB queries per dashboard request | Phase 9 |
| SEC-003 | CORS wildcard allow_origins=* | Phase 10 |
| FE-007 | dart:html breaks native builds | Phase 10 |
| GAP-006 | No user management API | Phase 10 |
| GAP-007 | No doc expiry / maintenance alerts | Phase 10 |
| GAP-008 | No frontend Phase 9+11 screens | Phase 10+11 |
| GAP-009 | No operational automation | Phase 10 |
| AUTH-004 | Hardcoded admin1234 | Phase 11 |
| GAP-005 | Subscription limits not enforced | Phase 11 |
| API-003 | No login rate limiting | Phase 11 |
