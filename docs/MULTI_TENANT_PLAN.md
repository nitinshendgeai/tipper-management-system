# Multi-Tenant Plan — Tipper Management ERP

**Version:** 2.0.0  
**Last Updated:** 2026-05-17  
**Phase:** System Stabilization  

---

## Current State

The platform transitioned from single-tenant to multi-tenant SaaS via Alembic migration `a1b2c3d4e5f6` (2026-05-11). The core isolation architecture is in place but several gaps remain from the hybrid migration state.

---

## Implemented

### Tenant Model
- Each company is represented by a `tenant.companies` row with a UUID primary key
- Company registration is self-service via `POST /companies/register`
- Per-company settings (`tenant.company_settings`): max_users, max_vehicles, subscription_tier

### Data Isolation
- All operational tables have `company_id UUID FK → tenant.companies.id`
- All authenticated queries go through `filter_by_company(query, Model)` which appends `WHERE company_id = <current>`
- Cascade deletes: deleting a company cascades to all child records

### Per-Request Tenant Context
- `TenantContext` uses Python `contextvars` for async-safe per-request isolation
- `get_current_tenant_user()` dependency extracts `company_id` from JWT and sets TenantContext
- Context is set at the start of every protected request and is not shared between requests

### Per-Company RBAC
- `tenant.user_roles` stores per-company role definitions with JSON permission arrays
- 4 default roles created per company: SUPER_ADMIN, MANAGER, SUPERVISOR, DRIVER
- Permissions are defined in `app/core/permissions.py` as a Python enum

### JWT Claims
- JWT includes `company_id` (UUID string) and `role_name`
- Token is verified and tenant context is set on every protected request

---

## Remaining Gaps

### GAP-001 — Login does not filter by company_id (Critical)
**Impact:** Two companies with a user sharing the same email → first DB match wins → wrong tenant.  
**Fix:** Add `company_id` or company slug to the login request payload.  
**Timeline:** Phase 2

### GAP-002 — Legacy auth system still active (Medium)
**Impact:** `auth.roles` and `auth.users.role_id` are still seeded and used by the admin endpoint. Two parallel auth systems exist.  
**Fix:** Deprecate `auth.roles` usage. Migrate admin endpoint to multi-tenant RBAC. Remove `role_id` column from `auth.users` in a future migration.  
**Timeline:** Phase 4

### GAP-003 — `company_id` is nullable on all data models (Medium)
**Impact:** No database-level enforcement of tenant isolation. Orphan rows (legacy data with `company_id = NULL`) could be returned by buggy queries.  
**Fix:** After verifying all rows have `company_id` populated, run a migration to set `nullable=False`.  
**Timeline:** Phase 4

### GAP-004 — Global unique constraints on vehicle_number and license_number (Medium)
**Impact:** Two different companies cannot register the same vehicle plate or driver license number — a real-world collision that will occur at scale.  
**Fix:** Change to composite unique constraints: `(company_id, vehicle_number)` and `(company_id, license_number)`.  
**Timeline:** Phase 4

### GAP-005 — No tenant-level feature flags or subscription enforcement (Low)
**Impact:** `subscription_tier` (basic/professional/enterprise) and `max_users`/`max_vehicles` are stored but never checked in any API.  
**Fix:** Add subscription gate checks in vehicle/user creation endpoints.  
**Timeline:** Phase 5

### GAP-006 — No company admin user management UI/API (Low)
**Impact:** The SUPER_ADMIN of a company cannot invite/manage other users via API.  
**Fix:** Build `/users/` CRUD endpoints scoped to the company.  
**Timeline:** Phase 3

---

## Target Architecture (Fully Multi-Tenant)

```
tenant.companies (one per customer)
    │
    ├── tenant.company_settings (limits, subscription)
    ├── tenant.user_roles (SUPER_ADMIN, MANAGER, SUPERVISOR, DRIVER)
    │
    ├── auth.users (all users, scoped by company_id)
    │
    ├── master.vehicles (company_id NOT NULL)
    ├── master.drivers (company_id NOT NULL, unique per company)
    ├── master.routes (company_id NOT NULL)
    ├── master.driver_vehicle_assignments (company_id NOT NULL)
    │
    ├── operations.trips (company_id NOT NULL)
    └── operations.trip_expenses (company_id NOT NULL)
```

---

## Migration Phases

| Phase | Action | Risk |
|---|---|---|
| Phase 2 (now) | Fix login to require company_id | Low — additive request field |
| Phase 3 | Add `/users/` management API | Low — new endpoints |
| Phase 4 | Make `company_id` NOT NULL on all tables | Medium — requires data validation first |
| Phase 4 | Fix unique constraints to be per-company | Medium — index changes |
| Phase 4 | Deprecate legacy auth.roles system | Medium — remove admin_api.py legacy path |
| Phase 5 | Enforce subscription limits | Low — gate checks only |

---

## Security Checklist for Multi-Tenancy

- [x] JWT carries `company_id` claim
- [x] All protected endpoints use `get_current_tenant_user` 
- [x] `filter_by_company()` applied to all data queries
- [x] Cascade deletes configured on FK relationships
- [ ] Login does not filter by company_id (GAP-001)
- [ ] `company_id` is nullable — no DB enforcement (GAP-003)
- [ ] Global unique constraints allow cross-tenant collisions (GAP-004)
- [ ] No subscription limit enforcement (GAP-005)
