# Test Checklist — Tipper Management ERP

**Version:** 7.0.0
**Last Updated:** 2026-05-19
**Phase:** Production Hardening + Full ERP Validation — Phase 7 Active

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
| H-03 | GET `/health` | `{"status":"ok"}` in <1ms — no DB required | |
| H-04 | GET `/health` after startup | `db_init_complete: true`, all 4 steps in `db_init_steps_done` | |
| H-05 | Railway healthcheck path | `/health` (not `/docs`) — configured in `railway.toml` | |
| H-06 | App restarts on failure | Railway ON_FAILURE policy active | |
| H-07 | Cold-start: Postgres not ready | App still serves /health (200) — DB init retries in background | |

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

---

## 15. Phase 3 Regression Tests (RBAC + Multi-Tenant Hardening)

### Backend — Tenant Query Scoping

| # | Test | Expected | Status |
|---|---|---|---|
| P3-01 | `GET /trips/` with enrichment — Company A token | Returns only Company A vehicle/driver/route names | |
| P3-02 | `GET /trips/{id}` — enriched vehicle/driver/route names | All resolved from correct company | |
| P3-03 | `GET /trips/{trip_id}/expenses` — Company A token | Returns only Company A expenses | |
| P3-04 | `POST /trips/{trip_id}/expenses` — add expense | trip.trip_expense recomputed, scoped to company | |
| P3-05 | `DELETE /trips/{trip_id}/expenses/{id}` — delete expense | Expense deleted, total recomputed correctly | |
| P3-06 | `GET /allocations/` with enriched response | Vehicle/driver names from correct company | |
| P3-07 | `GET /allocations/active` | Only active assignments from caller's company | |
| P3-08 | `user_id` included in JWT payload | `/auth/me` response includes user_id | |

### Frontend — Auth Token on GET Requests

| # | Test | Expected | Status |
|---|---|---|---|
| P3-09 | Open Vehicles screen (MANAGER login) | Loads vehicle list — no 401 error | |
| P3-10 | Open Drivers screen (MANAGER login) | Loads driver list — no 401 error | |
| P3-11 | Open Routes screen (MANAGER login) | Loads route list — no 401 error | |
| P3-12 | Open Trips screen (any login) | Loads trip list — no 401 error | |
| P3-13 | Open Trip detail | Loads single trip — no 401 error | |
| P3-14 | Open Allocation screen (SUPERVISOR+ login) | Loads assignments — no 401 error | |
| P3-15 | Dashboard stats load | Stats show correct counts — no 401 error | |
| P3-16 | Open trip expenses | Loads expense summary — no 401 error | |

### Frontend — Role-Based Navigation

| # | Test | Expected | Status |
|---|---|---|---|
| P3-17 | Login as DRIVER → open drawer | Sees: Dashboard, Trips only. Allocation and Master Data hidden | |
| P3-18 | Login as SUPERVISOR → open drawer | Sees: Dashboard, Trips, Shift Allocation. Master Data hidden | |
| P3-19 | Login as MANAGER → open drawer | Sees all items including Vehicles, Drivers, Routes | |
| P3-20 | Login as SUPER_ADMIN → open drawer | Sees all items | |
| P3-21 | Role badge shown in drawer header | Correct role_name displayed (e.g. "MANAGER") | |
| P3-22 | Logout clears role | After logout and re-login as different role, drawer reflects new role | |
| P3-23 | Token expiry → make GET request | DioError raised — user should be redirected to login (manual step; 401 interceptor Phase 4) | |

---

## 16. Phase 4 Regression Tests (Attendance + DRIVER Scope)

### Backend — Driver Attendance API

| # | Test | Expected | Status |
|---|---|---|---|
| P4-01 | `POST /attendance/punch-in` with MANAGER token + `driver_id` | 201, driver status=AVAILABLE | |
| P4-02 | `POST /attendance/punch-in` duplicate (already punched in today) | 409 Conflict | |
| P4-03 | `POST /attendance/punch-in` — driver already completed shift today | 409 Conflict | |
| P4-04 | `POST /attendance/punch-out` with MANAGER token + `driver_id` | 200, punch_out set, is_active=False | |
| P4-05 | `POST /attendance/punch-out` — driver is ON_TRIP | 409 — complete trip first | |
| P4-06 | `POST /attendance/punch-out` — no active shift for driver | 404 Not Found | |
| P4-07 | `GET /attendance/today` with SUPERVISOR token | Returns today's attendance records | |
| P4-08 | `GET /attendance/today` — cross-company token | Returns only own company records | |
| P4-09 | `GET /attendance/` with MANAGER token | Full history returned | |
| P4-10 | `GET /attendance/` with DRIVER token | 403 — use /me endpoint | |
| P4-11 | `GET /attendance/me` with DRIVER token (no user_id link) | 404 or empty (no driver profile) | |
| P4-12 | `GET /attendance/me` with DRIVER token (user_id linked) | Returns own attendance history | |
| P4-13 | `GET /dashboard/stats` — `drivers_on_duty` field | Returns count of active shifts today | |
| P4-14 | Punch in driver → check dashboard | `drivers_on_duty` incremented | |
| P4-15 | Punch out driver → check dashboard | `drivers_on_duty` decremented | |

### Backend — DRIVER-Scoped Trip Filtering

| # | Test | Expected | Status |
|---|---|---|---|
| P4-16 | `GET /trips/` with DRIVER token (user_id linked to driver) | Returns only this driver's trips | |
| P4-17 | `GET /trips/` with DRIVER token (no user_id link) | Returns empty list | |
| P4-18 | `GET /trips/` with SUPERVISOR token | Returns all company trips | |

### Backend — Driver Model Phase 4

| # | Test | Expected | Status |
|---|---|---|---|
| P4-19 | `POST /drivers/` with `user_id` in body | Driver created with user_id set | |
| P4-20 | `PUT /drivers/{id}` with `user_id` in body | Driver updated, user_id linked | |
| `GET /drivers/{id}` | Response includes `user_id` field | |

### Frontend — Attendance Screen

| # | Test | Expected | Status |
|---|---|---|---|
| P4-21 | Open Attendance screen as DRIVER (no punch-in today) | "Not yet on duty" card with Punch In button | |
| P4-22 | DRIVER taps Punch In | Record created, card switches to ON DUTY | |
| P4-23 | DRIVER taps Punch Out | Shift ends, duration shown | |
| P4-24 | Open Attendance screen as SUPERVISOR | Today's full company list shown | |
| P4-25 | SUPERVISOR taps "Punch In Driver" + enters driver_id | Driver punched in, list refreshes | |
| P4-26 | SUPERVISOR taps Punch Out on active card | Confirm dialog → punch out | |
| P4-27 | Attendance menu item visible to DRIVER in drawer | Menu item "Attendance" shown | |
| P4-28 | Attendance menu item visible to SUPERVISOR in drawer | Menu item "Attendance" shown | |

### Frontend — Dashboard Attendance Row

| # | Test | Expected | Status |
|---|---|---|---|
| P4-29 | Open dashboard — "Attendance Today" row visible | Shows: On Duty, Available, On Trip, Off Duty pills | |
| P4-30 | Punch in a driver → refresh dashboard | `On Duty` count incremented | |

### Frontend — 401 Interceptor

| # | Test | Expected | Status |
|---|---|---|---|
| P4-31 | Use expired token → make any authenticated request | App redirects to login screen | |
| P4-32 | Redirected to login → login with valid credentials | Works normally, new token stored | |

---

## Phase 5 Tests — Analytics + Dashboard Intelligence

### Analytics API — Operational KPIs

| # | Test | Expected | Status |
|---|---|---|---|
| P5-01 | GET `/analytics/operational` as MANAGER (no period param) | 200, defaults to today window | |
| P5-02 | GET `/analytics/operational?period=week` as MANAGER | 200, week window data returned | |
| P5-03 | GET `/analytics/operational?period=month` as MANAGER | 200, month window data returned | |
| P5-04 | GET `/analytics/operational?period=last_30_days` as MANAGER | 200, 30-day window returned | |
| P5-05 | GET `/analytics/operational` as DRIVER | 403 Forbidden (VIEW_ANALYTICS required) | |
| P5-06 | GET `/analytics/operational` as SUPERVISOR | 403 Forbidden | |
| P5-07 | Verify `trip_completion_rate` = completed / total * 100 | Mathematically correct | |
| P5-08 | Verify `net_revenue` = total_revenue - diesel - expenses | Mathematically correct | |

### Analytics API — Fleet

| # | Test | Expected | Status |
|---|---|---|---|
| P5-09 | GET `/analytics/fleet` as MANAGER | 200, all vehicles listed | |
| P5-10 | GET `/analytics/fleet?period=week` | Vehicle stats scoped to this week only | |
| P5-11 | Vehicles sorted by total_trips descending | Most active vehicle first | |
| P5-12 | GET `/analytics/fleet` as DRIVER | 403 Forbidden | |
| P5-13 | Verify `avg_trips_per_vehicle` = total_trips_all / vehicle_count | Mathematically correct | |

### Analytics API — Driver Self-Stats

| # | Test | Expected | Status |
|---|---|---|---|
| P5-14 | GET `/analytics/driver/me` as DRIVER (with user_id linked) | 200, driver's own stats | |
| P5-15 | GET `/analytics/driver/me` as MANAGER | 403 Forbidden | |
| P5-16 | GET `/analytics/driver/me` as DRIVER (no user_id link) | 404 Not Found | |
| P5-17 | `punched_in_today` = true when driver has punch-in today | Correct | |
| P5-18 | `punch_in_time` returned when punched in today | Non-null datetime | |

### Analytics API — Smart Alerts

| # | Test | Expected | Status |
|---|---|---|---|
| P5-19 | GET `/analytics/alerts` as MANAGER | 200, alerts list returned | |
| P5-20 | GET `/analytics/alerts` as DRIVER | 200 (uses VIEW_DASHBOARD — all roles) | |
| P5-21 | Start a trip > 8 hours ago → check alerts | OVERDUE_TRIP alert present, severity HIGH | |
| P5-22 | Log expense > ₹10,000 on a recent trip | EXCESSIVE_EXPENSE alert present | |
| P5-23 | < 50% drivers punched in today | LOW_ATTENDANCE alert present | |
| P5-24 | Vehicle AVAILABLE with no trips in 7+ days | INACTIVE_VEHICLE alert present | |
| P5-25 | > 20% cancellations this week | HIGH_CANCELLATION alert present | |
| P5-26 | Alerts sorted: HIGH before MEDIUM before LOW | Sort order verified | |
| P5-27 | Alerts from Company A not visible in Company B | Tenant isolation verified | |

### Analytics API — Supervisor Snapshot

| # | Test | Expected | Status |
|---|---|---|---|
| P5-28 | GET `/analytics/supervisor/snapshot` as SUPERVISOR | 200, today's operational counts | |
| P5-29 | `trips_completed_today` matches dashboard today count | Consistent with dashboard | |
| P5-30 | `drivers_on_duty` matches attendance today count | Consistent with attendance | |

### Dashboard API — Phase 5 Fields

| # | Test | Expected | Status |
|---|---|---|---|
| P5-31 | GET `/dashboard/stats` — new fields present in response | trips_today, revenue_today, trip_completion_rate, etc. | |
| P5-32 | `trips_today` = all trips created today (regardless of status) | Correct count | |
| P5-33 | `revenue_today` = sum of completed trip revenue today | Correct amount | |
| P5-34 | `revenue_this_month` = sum of completed trip revenue this month | Correct amount | |
| P5-35 | `avg_revenue_per_trip` is all-time average (all completed trips) | Consistent with total_revenue / trips_completed | |

### Frontend Dashboard — Phase 5 UI

| # | Test | Expected | Status |
|---|---|---|---|
| P5-36 | Dashboard loads — "Today's KPIs" row visible | 4 pills: Trips, Done, Revenue, This Month | |
| P5-37 | Dashboard loads — "Performance Metrics" row visible | Completion %, Avg Rev/Trip, Utilisation, Net Revenue | |
| P5-38 | "Trips Today" card shows today's trips (not trips_active) | Uses `tripsToday` field | |
| P5-39 | Net Revenue shows red when negative | Color changes to red correctly | |
| P5-40 | Loading state: Phase 5 pills show spinner | CircularProgressIndicator visible during load | |

### Tenant Isolation — Analytics

| # | Test | Expected | Status |
|---|---|---|---|
| P5-41 | Company A and B both have trips — GET /analytics/operational | Each sees only own metrics | |
| P5-42 | Company A vehicle inactive — Company B should NOT see alert | Company B alerts only for own fleet | |
| P5-43 | Concurrent requests from two companies | Correct tenant context preserved per request | |

---

## Phase 6 Tests — Production Hardening

### Deployment + Healthcheck

| # | Test | Expected | Status |
|---|---|---|---|
| P6-01 | GET `/health` immediately after cold start | `{"status":"ok"}` in <1ms before DB ready | |
| P6-02 | GET `/health` after ~10s | `db_init_complete: true`, all 4 steps done | |
| P6-03 | Railway Logs → filter `[bg-init]` | 4 step lines with timing, final "complete in X.Xs" | |
| P6-04 | Railway healthcheck tab | Status shows green / healthy | |

### Auth — Company-Scoped Login (AUTH-001)

| # | Test | Expected | Status |
|---|---|---|---|
| P6-05 | POST `/auth/login` with valid `company_slug` | 200, token scoped to correct company | |
| P6-06 | POST `/auth/login` with wrong `company_slug` | 401 "Invalid company name, email, or password" | |
| P6-07 | POST `/auth/login` without `company_slug` | 200, backward-compatible (email-only lookup) | |
| P6-08 | Flutter login screen — Company Name field present | Text field visible on login screen | |
| P6-09 | Two companies, same email — login with slug | Returns correct tenant user only | |

### Duplicate Trip Guard (ATTEND-002)

| # | Test | Expected | Status |
|---|---|---|---|
| P6-10 | Create trip, then create another for same vehicle (status=CREATED) | 409 "Vehicle already has an active trip" | |
| P6-11 | Start trip, then try create another for same vehicle | 409 Conflict | |

### Performance — N+1 Fixes

| # | Test | Expected | Status |
|---|---|---|---|
| P6-12 | GET `/analytics/fleet` with 20 vehicles | Single response, no timeout | |
| P6-13 | GET `/analytics/alerts` with 20+ vehicles/drivers | Fast response, no N+1 loop | |

### Flutter — DioClient Migration

| # | Test | Expected | Status |
|---|---|---|---|
| P6-14 | Use expired token in app → make any request | Redirected to login screen automatically | |
| P6-15 | Server returns `{"detail": "Vehicle not found"}` on error | Flutter snackbar shows that exact message | |
| P6-16 | Network offline → make any request | "Cannot reach the server" message shown | |

### DB Indexes (PERF-001)

| # | Test | Expected | Status |
|---|---|---|---|
| P6-17 | GET `/health` after deploy — `repair_schema` in steps_done | Confirms indexes were created | |
| P6-18 | `SELECT * FROM pg_indexes WHERE tablename='trips'` | 5+ indexes visible including composite | |

---

## Phase 7 Tests — Full ERP Validation

### RBAC Fix — SUPERVISOR Lifecycle (RBAC-007)

| # | Test | Expected | Status |
|---|---|---|---|
| P7-01 | SUPERVISOR token → `POST /allocations/` | 200, assignment created (was 403 before fix) | |
| P7-02 | SUPERVISOR token → `PUT /trips/{id}/start` | 200, trip started (was 403 before fix) | |
| P7-03 | SUPERVISOR token → `PUT /trips/{id}/complete` | 200, trip completed (was 403 before fix) | |
| P7-04 | SUPERVISOR token → `PUT /trips/{id}/cancel` | 200, trip cancelled (was 403 before fix) | |
| P7-05 | SUPERVISOR token → `PUT /allocations/{id}/release` | 200, assignment released (was 403 before fix) | |
| P7-06 | DRIVER token → `PUT /trips/{id}/start` | 403 Forbidden (DRIVER still blocked correctly) | |

### Security — Route Intelligence Auth (SEC-002)

| # | Test | Expected | Status |
|---|---|---|---|
| P7-07 | `POST /route-intelligence/calculate` without token | 403 Forbidden (was 200 before fix) | |
| P7-08 | `POST /route-intelligence/calculate` with SUPERVISOR token | 200, route calculated | |
| P7-09 | `POST /route-intelligence/calculate` with DRIVER token | 403 Forbidden (needs CREATE_TRIPS) | |

### Security — Exception Leak Fix (TENANT-004)

| # | Test | Expected | Status |
|---|---|---|---|
| P7-10 | `POST /companies/register` triggers DB error | 500 with generic message, no Python trace | |

### Full Operational Scenario — Scenario 1

| # | Test | Description | Status |
|---|---|---|---|
| SC1-01 | Register company | POST /companies/register → 201 | |
| SC1-02 | Login as admin | POST /auth/login with company_slug → token | |
| SC1-03 | Create driver | POST /drivers/ as MANAGER → 201 | |
| SC1-04 | Create vehicle | POST /vehicles/ as MANAGER → 201 | |
| SC1-05 | Assign driver to vehicle | POST /allocations/ as SUPERVISOR → 201, vehicle=ASSIGNED | |
| SC1-06 | Get route estimate | POST /route-intelligence/calculate as SUPERVISOR → distance/diesel | |
| SC1-07 | Create trip | POST /trips/ as SUPERVISOR with vehicle_id → 201, driver auto-fetched | |
| SC1-08 | Start trip | PUT /trips/{id}/start as SUPERVISOR → STARTED, vehicle=ON_TRIP | |
| SC1-09 | Add expense | POST /trips/{id}/expenses as SUPERVISOR → expense logged | |
| SC1-10 | Complete trip | PUT /trips/{id}/complete as SUPERVISOR → COMPLETED, vehicle=ASSIGNED | |
| SC1-11 | Check dashboard | GET /dashboard/stats → trips_completed incremented | |
| SC1-12 | Release allocation | PUT /allocations/{id}/release as SUPERVISOR → AVAILABLE | |

### Full Operational Scenario — Scenario 2 (Multi-Tenant Isolation)

| # | Test | Description | Status |
|---|---|---|---|
| SC2-01 | Register Company A and Company B | Two separate registrations | |
| SC2-02 | Login as Company A admin | Get token-A | |
| SC2-03 | Login as Company B admin | Get token-B | |
| SC2-04 | Create vehicle in Company A | Use token-A | |
| SC2-05 | GET /vehicles/ with token-B | Returns 0 (Company A vehicle not visible) | |
| SC2-06 | Create trip in Company A | Use token-A | |
| SC2-07 | GET /trips/ with token-B | Returns 0 (Company A trip not visible) | |
| SC2-08 | GET /dashboard/stats with token-A | Shows Company A counts only | |
| SC2-09 | GET /dashboard/stats with token-B | Shows Company B counts only (different) | |
| SC2-10 | Try to cancel Company A trip with token-B | 404 Not Found | |

### Full Operational Scenario — Scenario 3 (RBAC Matrix)

| # | Test | Role | Expected | Status |
|---|---|---|---|---|
| SC3-01 | POST `/vehicles/` | DRIVER | 403 | |
| SC3-02 | POST `/vehicles/` | SUPERVISOR | 403 | |
| SC3-03 | POST `/vehicles/` | MANAGER | 201 | |
| SC3-04 | POST `/allocations/` | DRIVER | 403 | |
| SC3-05 | POST `/allocations/` | SUPERVISOR | 201 | |
| SC3-06 | PUT `/trips/{id}/start` | DRIVER | 403 | |
| SC3-07 | PUT `/trips/{id}/start` | SUPERVISOR | 200 | |
| SC3-08 | GET `/analytics/operational` | DRIVER | 403 | |
| SC3-09 | GET `/analytics/operational` | SUPERVISOR | 403 | |
| SC3-10 | GET `/analytics/operational` | MANAGER | 200 | |
| SC3-11 | GET `/analytics/driver/me` | DRIVER | 200 | |
| SC3-12 | GET `/analytics/driver/me` | MANAGER | 403 | |
| SC3-13 | POST `/route-intelligence/calculate` | no token | 403 | |
| SC3-14 | POST `/route-intelligence/calculate` | SUPERVISOR | 200 | |
