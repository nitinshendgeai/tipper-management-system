# Test Checklist — Tipper Management ERP

**Version:** 2.0.0  
**Last Updated:** 2026-05-17  
**Phase:** System Stabilization  

---

## How to Use This Checklist

Run these tests manually via:
- Swagger UI: `https://tipper-management-system.up.railway.app/docs`
- Postman / curl

Mark each item: ✅ Pass | ❌ Fail | ⏭️ Skip | 🔄 Retest

---

## 1. Deployment Health

| # | Test | Expected | Status |
|---|---|---|---|
| H-01 | GET `/docs` | Swagger UI loads (200) | |
| H-02 | GET `/openapi.json` | JSON schema loads (200) | |
| H-03 | Railway health check path `/docs` | 200 within 300s timeout | |
| H-04 | App restarts on failure | Railway ON_FAILURE policy active | |

---

## 2. Company Registration

| # | Test | Expected | Status |
|---|---|---|---|
| R-01 | POST `/companies/register` with valid data | 201, company created | |
| R-02 | POST `/companies/register` duplicate company_name | 409 Conflict | |
| R-03 | POST `/companies/register` duplicate email | 409 Conflict | |
| R-04 | Verify admin user created | `admin@<slug>.com` exists in DB | |
| R-05 | Verify 4 user_roles created per company | SUPER_ADMIN, MANAGER, SUPERVISOR, DRIVER | |
| R-06 | Verify company_settings created | max_users=50, max_vehicles=100, basic tier | |
| R-07 | GET `/companies/{id}` | Company details + live counts returned | |
| R-08 | GET `/companies/{invalid-uuid}` | 400 Bad Request | |
| R-09 | GET `/companies/{non-existent-uuid}` | 404 Not Found | |

---

## 3. Authentication

| # | Test | Expected | Status |
|---|---|---|---|
| A-01 | POST `/auth/login` with valid credentials | 200, access_token returned | |
| A-02 | POST `/auth/login` wrong password | 401 Unauthorized | |
| A-03 | POST `/auth/login` unknown email | 401 Unauthorized | |
| A-04 | GET `/auth/me` with valid token | 200, user profile returned | |
| A-05 | GET `/auth/me` without token | 403 Forbidden | |
| A-06 | GET `/auth/me` with expired token | 401 Unauthorized | |
| A-07 | GET `/auth/me` with malformed token | 401 Unauthorized | |
| A-08 | JWT contains company_id, role_name, sub | Decoded payload has all fields | |
| A-09 | Two companies — same email login | Returns correct company tenant ⚠️ Known Issue AUTH-001 | |

---

## 4. Vehicle CRUD

| # | Test | Expected | Status |
|---|---|---|---|
| V-01 | POST `/vehicles/` with SUPER_ADMIN token | 201, vehicle created | |
| V-02 | POST `/vehicles/` with SUPERVISOR token | 403 Forbidden | |
| V-03 | GET `/vehicles/` | Returns only this company's vehicles | |
| V-04 | GET `/vehicles/` with another company's token | Returns zero vehicles from first company | |
| V-05 | GET `/vehicles/{id}` | Returns single vehicle | |
| V-06 | GET `/vehicles/{id}` from different company | 404 (not visible cross-tenant) | |
| V-07 | PUT `/vehicles/{id}` | Updated vehicle returned | |
| V-08 | DELETE `/vehicles/{id}` | Soft-deleted (is_active=False) | |
| V-09 | Duplicate vehicle_number | 409 Conflict | |
| V-10 | Vehicle default status | AVAILABLE | |

---

## 5. Driver CRUD

| # | Test | Expected | Status |
|---|---|---|---|
| D-01 | POST `/drivers/` with SUPER_ADMIN token | 201, driver created | |
| D-02 | GET `/drivers/` | Returns only this company's drivers | |
| D-03 | Duplicate license_number | 409 Conflict ⚠️ Global unique — see BIZ-003 | |
| D-04 | Driver default status | OFF_DUTY | |

---

## 6. Route CRUD

| # | Test | Expected | Status |
|---|---|---|---|
| RT-01 | POST `/routes/` | 201, route created | |
| RT-02 | GET `/routes/` | Returns company-scoped routes only | |
| RT-03 | PUT `/routes/{id}` | Updated route returned | |
| RT-04 | DELETE `/routes/{id}` | Soft-deleted | |

---

## 7. Shift Allocation

| # | Test | Expected | Status |
|---|---|---|---|
| AL-01 | POST `/allocations/` | Assignment created, vehicle=ASSIGNED | |
| AL-02 | GET `/allocations/active` | Returns active assignments only | |
| AL-03 | GET `/allocations/vehicle/{vehicle_id}` | Returns assignments for that vehicle | |
| AL-04 | GET `/allocations/driver/{driver_id}` | Returns assignments for that driver | |
| AL-05 | PUT `/allocations/{id}/release` | is_active=False, statuses reverted | |

---

## 8. Route Intelligence

| # | Test | Expected | Status |
|---|---|---|---|
| RI-01 | POST `/route-intelligence/calculate` valid locations | Distance, duration, diesel returned | |
| RI-02 | Response includes `source` field | "google_maps" or "formula_estimate" | |
| RI-03 | Without GOOGLE_MAPS_API_KEY | Falls back to formula estimate | |

---

## 9. Trip Lifecycle

| # | Test | Expected | Status |
|---|---|---|---|
| T-01 | POST `/trips/` with valid vehicle (assigned driver) | Trip created, status=CREATED | |
| T-02 | POST `/trips/` with vehicle that has no assignment | 409 Conflict | |
| T-03 | POST `/trips/` with vehicle ON_TRIP | 409 Conflict | |
| T-04 | POST `/trips/` with vehicle MAINTENANCE | 409 Conflict | |
| T-05 | PUT `/trips/{id}/start` on CREATED trip | status=STARTED, vehicle=ON_TRIP, driver=ON_TRIP | |
| T-06 | PUT `/trips/{id}/start` on STARTED trip | 409 Conflict | |
| T-07 | PUT `/trips/{id}/start` on COMPLETED trip | 409 Conflict | |
| T-08 | PUT `/trips/{id}/complete` with end_km > start_km | status=COMPLETED | |
| T-09 | PUT `/trips/{id}/complete` with end_km <= start_km | 422 Validation error | |
| T-10 | Trip complete — vehicle reverts to ASSIGNED (active assignment) | vehicle.status=ASSIGNED | |
| T-11 | Trip complete — vehicle reverts to AVAILABLE (no active assignment) | vehicle.status=AVAILABLE | |
| T-12 | PUT `/trips/{id}/cancel` on CREATED trip | status=CANCELLED | |
| T-13 | PUT `/trips/{id}/cancel` on STARTED trip | 409 — only CREATED can be cancelled | |
| T-14 | GET `/trips/?status=COMPLETED` | Only completed trips returned | |
| T-15 | GET `/trips/` with DRIVER token | Returns trips only from this company | |
| T-16 | GET `/trips/{id}` cross-company | 404 (not visible) | |

---

## 10. Trip Expenses

| # | Test | Expected | Status |
|---|---|---|---|
| E-01 | POST `/trips/{id}/expenses` | Expense created | |
| E-02 | GET `/trips/{id}/expenses` | List of expenses returned | |
| E-03 | DELETE `/trips/{id}/expenses/{expense_id}` | Expense deleted | |
| E-04 | Complete trip with expenses logged | trip_expense = sum of logged expenses | |

---

## 11. Dashboard

| # | Test | Expected | Status |
|---|---|---|---|
| DS-01 | GET `/dashboard/stats` | All counters returned (no zero errors) | |
| DS-02 | All counts are company-scoped | Different company → different numbers | |
| DS-03 | `utilisation_pct` calculated correctly | (on_trip / active_fleet) * 100 | |
| DS-04 | After completing a trip | trips_completed incremented, trips_active decremented | |
| DS-05 | Revenue aggregation | total_revenue = sum of completed trip revenue_amount | |

---

## 12. RBAC Enforcement

| # | Test | Expected | Status |
|---|---|---|---|
| RB-01 | DRIVER token → POST `/vehicles/` | 403 Forbidden | |
| RB-02 | DRIVER token → GET `/dashboard/stats` | 200 OK | |
| RB-03 | SUPERVISOR token → POST `/trips/` | 200 OK | |
| RB-04 | SUPERVISOR token → POST `/vehicles/` | 403 Forbidden | |
| RB-05 | MANAGER token → GET `/vehicles/` | 200 OK | |
| RB-06 | Token with invalid role_name | 403 Forbidden (empty permissions) | |

---

## 13. Multi-Tenant Isolation

| # | Test | Expected | Status |
|---|---|---|---|
| MT-01 | Company A vehicle not visible to Company B | GET /vehicles/ returns 0 for Company B | |
| MT-02 | Company A driver not visible to Company B | GET /drivers/ returns 0 for Company B | |
| MT-03 | Company A trip not visible to Company B | GET /trips/ returns 0 for Company B | |
| MT-04 | Company A dashboard counts do not include Company B data | Counts differ correctly | |
| MT-05 | Company A cannot cancel Company B trip | 404 (not found in tenant scope) | |

---

## 14. Phase 2 Regression Tests (After Stabilization Fixes)

| # | Test | Expected | Status |
|---|---|---|---|
| P2-01 | Startup on clean database | Schemas created, app starts, /docs loads | |
| P2-02 | `repair_existing_schema()` called on startup | No crash if columns already exist (IF NOT EXISTS guards) | |
| P2-03 | `/auth/me` — tenant isolation verified | Only returns user from correct company | |
| P2-04 | `get_db()` usage consistent | trip_api, dashboard_api use dependency injection | |
| P2-05 | `role_id` lookup dynamic, not hardcoded | Works even if Admin role has id != 1 | |
