# API Flow — Tipper Management ERP

**Version:** 6.0.0  
**Last Updated:** 2026-05-20  
**Phase:** Enterprise ERP Expansion — Phase 9 Complete  
**Base URL (Production):** `https://tipper-management-system.up.railway.app`  
**Docs URL:** `https://tipper-management-system.up.railway.app/docs`

---

## Public Endpoints (No Auth Required)

| Method | Path | Description |
|---|---|---|
| `POST` | `/companies/register` | Register a new company (onboarding) |
| `POST` | `/auth/login` | Authenticate user, receive JWT |

---

## Protected Endpoints (Bearer Token Required)

All requests to protected endpoints must include:
```
Authorization: Bearer <access_token>
```

---

## Operational Flow Sequence

### 1. Company Onboarding

```
POST /companies/register
Body: {
  company_name, owner_name, mobile_number,
  email, gst_number, address
}

Response: {
  id (UUID), company_name, owner_name, mobile_number,
  email, gst_number, address, is_active, created_at
}

Side effects:
  → Creates tenant.companies row
  → Creates tenant.company_settings (basic, 50 users, 100 vehicles)
  → Creates 4 tenant.user_roles (SUPER_ADMIN, MANAGER, SUPERVISOR, DRIVER)
  → Creates admin user: admin@<company-slug>.com / admin1234
```

---

### 2. Authentication

```
POST /auth/login
Body: { email, password }

Response: { access_token, token_type: "bearer" }

JWT Payload: {
  sub: user@email.com,
  role_id: 1,               ← legacy field
  role_name: "SUPER_ADMIN", ← RBAC check field
  company_id: "uuid-string",← tenant isolation field
  exp: timestamp
}
```

```
GET /auth/me
Headers: Authorization: Bearer <token>

Response: {
  id, full_name, email, role_id, company_id, user_role_id
}
```

---

### 3. Master Data Setup

#### Vehicles

```
POST /vehicles/            → Create vehicle     (MANAGE_VEHICLES)
GET  /vehicles/            → List vehicles      (VIEW_VEHICLES)
GET  /vehicles/{id}        → Get vehicle        (VIEW_VEHICLES)
PUT  /vehicles/{id}        → Update vehicle     (MANAGE_VEHICLES)
DELETE /vehicles/{id}      → Soft-delete        (MANAGE_VEHICLES)

Body (POST/PUT): {
  vehicle_number, vehicle_type, capacity_ton,
  owner_name, mobile_number, rc_number, insurance_expiry
}

Response includes: status (AVAILABLE|ASSIGNED|ON_TRIP|MAINTENANCE)
```

#### Drivers

```
POST /drivers/             → Create driver      (MANAGE_DRIVERS)
GET  /drivers/             → List drivers       (VIEW_DRIVERS)
GET  /drivers/{id}         → Get driver         (VIEW_DRIVERS)
PUT  /drivers/{id}         → Update driver      (MANAGE_DRIVERS)
DELETE /drivers/{id}       → Soft-delete        (MANAGE_DRIVERS)

Body (POST/PUT): {
  full_name, mobile_number, license_number,
  license_expiry, aadhaar_number, address, emergency_contact
}

Response includes: status (OFF_DUTY|AVAILABLE|ON_TRIP|BREAK)
```

#### Routes

```
POST /routes/              → Create route       (MANAGE_ROUTES)
GET  /routes/              → List routes        (VIEW_ROUTES)
GET  /routes/{id}          → Get route          (VIEW_ROUTES)
PUT  /routes/{id}          → Update route       (MANAGE_ROUTES)
DELETE /routes/{id}        → Soft-delete        (MANAGE_ROUTES)

Body (POST/PUT): {
  source_location, destination_location, distance_km,
  trip_rate, diesel_limit, estimated_hours, remarks
}
```

---

### 4. Shift Allocation

```
POST /allocations/
Body: { vehicle_id, driver_id, shift_date, remarks }
Effect: vehicle.status → ASSIGNED, driver.status → AVAILABLE
Permission: MANAGE_TRIPS

GET /allocations/active    → Active assignments only
GET /allocations/          → All assignments (history)
GET /allocations/{id}      → Single assignment
GET /allocations/vehicle/{vehicle_id}  → By vehicle
GET /allocations/driver/{driver_id}    → By driver

PUT /allocations/{id}/release
Effect: is_active=False, vehicle.status → AVAILABLE, driver.status → OFF_DUTY
```

---

### 5. Route Intelligence

```
POST /route-intelligence/calculate
Permission: CREATE_TRIPS (Phase 7 SEC-002 fix — was public, now requires auth)
Headers: Authorization: Bearer <token>
Body: { source_location, destination_location }

Response: {
  source_location,
  destination_location,
  distance_km,
  duration_minutes,
  estimated_diesel_litres,
  source: "google_maps" | "formula_estimate"
}

Available to: SUPERVISOR, MANAGER, SUPER_ADMIN (CREATE_TRIPS permission).
DRIVER role is blocked (no CREATE_TRIPS permission).
```

---

### 6. Trip Lifecycle

#### Create Trip

```
POST /trips/
Permission: CREATE_TRIPS
Body: {
  vehicle_id,
  route_id (optional),
  source_location, destination_location,
  calculated_distance_km, estimated_duration_min, estimated_diesel,
  distance_km_override,
  diesel_issued, trip_advance, remarks
}

Auto-fetches: driver from active vehicle assignment
Effect: trip created with status=CREATED

Response: TripResponse { id, trip_status, vehicle_id, driver_id, ... }
```

#### Start Trip

```
PUT /trips/{id}/start
Permission: MANAGE_TRIPS
Body: { start_km }

Transition: CREATED → STARTED
Effect: vehicle.status → ON_TRIP, driver.status → ON_TRIP
```

#### Complete Trip

```
PUT /trips/{id}/complete
Permission: MANAGE_TRIPS
Body: {
  end_km,          ← must be > start_km
  diesel_used,
  revenue_amount,
  remarks (optional)
}

Transition: STARTED → COMPLETED
Effect: vehicle.status → ASSIGNED (if assignment still active) or AVAILABLE
        driver.status → AVAILABLE
        trip_expense set to sum of TripExpense records
```

#### Cancel Trip

```
PUT /trips/{id}/cancel
Permission: MANAGE_TRIPS
Body: { cancellation_reason }

Transition: CREATED → CANCELLED (only CREATED trips can be cancelled)
Effect: vehicle/driver statuses restored
```

#### List Trips

```
GET /trips/
Permission: VIEW_TRIPS
Query params:
  status=CREATED|STARTED|COMPLETED|CANCELLED
  vehicle_id=<int>
  driver_id=<int>

Response: list[TripListItem] with enriched vehicle_number, driver_name, route_label
```

---

### 7. Trip Expenses

```
POST /trips/{trip_id}/expenses
Body: {
  expense_type: Diesel|Toll|Food/Bata|Repair|Puncture|Police|Other,
  amount,
  remarks (optional)
}

GET /trips/{trip_id}/expenses
Response: list of expense records

DELETE /trips/{trip_id}/expenses/{expense_id}
```

---

### 8. Dashboard Analytics

```
GET /dashboard/stats
Permission: VIEW_DASHBOARD

Response: {
  total_vehicles, total_drivers, total_routes,

  vehicles_available, vehicles_assigned, vehicles_on_trip, vehicles_maintenance,
  drivers_available, drivers_on_trip, drivers_off_duty,
  drivers_on_duty,      ← Phase 4: punched in today, shift still active

  trips_total, trips_created, trips_active, trips_completed, trips_cancelled,

  total_revenue,        ← sum of completed trip revenue_amount (all-time)
  total_diesel_used,    ← sum of completed trip diesel_used (all-time)
  total_trip_expenses,  ← sum of all trip_expenses.amount (all-time)

  utilisation_pct,      ← (on_trip / active_fleet) * 100

  -- Phase 5 fields (Optional — default 0 on old backends) --
  trips_today,              ← total trips created today
  trips_completed_today,    ← trips completed today
  revenue_today,            ← revenue from completed trips today
  revenue_this_month,       ← revenue from completed trips this month
  trip_completion_rate,     ← completed / (completed + cancelled) * 100 (all-time)
  avg_revenue_per_trip,     ← average revenue per completed trip (all-time)
  avg_diesel_per_trip       ← average diesel litres per completed trip (all-time)
}
```

---

### 9. Analytics Engine (Phase 5)

```
GET /analytics/operational?period=today|week|month|last_30_days
Permission: VIEW_ANALYTICS (MANAGER, SUPER_ADMIN)

Response: OperationalKPIs {
  window: { period, from_date, to_date },
  trips_created, trips_started, trips_completed, trips_cancelled, trip_completion_rate,
  total_revenue, total_diesel_expense, total_trip_expenses, net_revenue,
  avg_revenue_per_trip, avg_expense_per_trip,
  total_distance_km, total_diesel_litres, avg_fuel_efficiency_km_per_litre,
  total_driver_shifts
}

GET /analytics/fleet?period=today|week|month|last_30_days
Permission: VIEW_ANALYTICS (MANAGER, SUPER_ADMIN)

Response: FleetAnalytics {
  window, total_vehicles, active_vehicles, utilisation_pct, avg_trips_per_vehicle,
  top_vehicles: [ VehicleUtilization { vehicle_id, vehicle_number, total_trips,
                  total_distance_km, total_revenue, total_diesel_used, current_status } ]
}

GET /analytics/driver/me?period=today|week|month|last_30_days
Permission: VIEW_TRIPS (DRIVER role only — enforced in handler)

Response: DriverSelfStats {
  window, driver_name, total_trips, trips_completed, trips_cancelled,
  total_distance_km, total_revenue_generated, total_expenses_logged,
  total_shifts, current_status, punched_in_today, punch_in_time
}

GET /analytics/alerts
Permission: VIEW_DASHBOARD (all authenticated roles)

Response: AlertsResponse {
  total_alerts, critical_count, high_count,
  alerts: [ OperationalAlert {
    alert_type, severity, title, message,
    entity_type, entity_id, entity_label, triggered_at
  } ]
}
Alert types: OVERDUE_TRIP | EXCESSIVE_EXPENSE | LOW_ATTENDANCE |
             INACTIVE_VEHICLE | INACTIVE_DRIVER | HIGH_CANCELLATION

GET /analytics/supervisor/snapshot
Permission: VIEW_DASHBOARD (all authenticated roles)

Response: SupervisorSnapshot {
  today, drivers_on_duty, drivers_off_duty, drivers_on_trip,
  active_assignments, trips_created_today, trips_started_today,
  trips_completed_today, pending_trips
}
```

---

### 10. Maintenance Management (Phase 9)

```
POST /maintenance/
Permission: MANAGE_MAINTENANCE (MANAGER, SUPER_ADMIN)
Body: {
  vehicle_id,
  maintenance_type: ROUTINE | REPAIR | TYRE | INSPECTION | OTHER,
  description,
  scheduled_date (optional),
  cost (optional, >= 0),
  odometer_km (optional),
  vendor_name (optional),
  notes (optional)
}
Response: MaintenanceResponse { id, vehicle_id, vehicle_number, maintenance_type,
           status, description, scheduled_date, completed_date, cost, ... }

GET /maintenance/                     → List all for company        (VIEW_MAINTENANCE)
GET /maintenance/{id}                 → Get single record           (VIEW_MAINTENANCE)
PUT /maintenance/{id}                 → Update (status, cost, etc.) (MANAGE_MAINTENANCE)
DELETE /maintenance/{id}              → Delete record               (MANAGE_MAINTENANCE)
GET /maintenance/vehicle/{vehicle_id} → By-vehicle history          (VIEW_MAINTENANCE)

Status FSM: SCHEDULED → IN_PROGRESS → COMPLETED / CANCELLED

Available to:
  SUPER_ADMIN, MANAGER  → full CRUD (MANAGE_MAINTENANCE)
  SUPERVISOR            → read-only (VIEW_MAINTENANCE)
```

---

### 11. Fuel Management (Phase 9)

```
POST /fuel/
Permission: MANAGE_FUEL (SUPERVISOR, MANAGER, SUPER_ADMIN)
Body: {
  vehicle_id,
  fuel_date,
  quantity_litres (> 0),
  cost_per_litre (optional),
  total_cost (auto-computed if cost_per_litre provided),
  driver_id (optional),
  trip_id (optional),
  odometer_km (optional),
  fuel_station (optional),
  notes (optional)
}
Response: FuelEntryResponse { id, vehicle_id, vehicle_number, driver_id, driver_name,
           trip_id, fuel_date, quantity_litres, cost_per_litre, total_cost, ... }

GET /fuel/                        → List all entries for company   (VIEW_FUEL)
GET /fuel/analytics               → Aggregate analytics            (VIEW_FUEL)
GET /fuel/{id}                    → Get single entry               (VIEW_FUEL)
PUT /fuel/{id}                    → Update entry                   (MANAGE_FUEL)
DELETE /fuel/{id}                 → Delete entry                   (MANAGE_FUEL)
GET /fuel/vehicle/{vehicle_id}    → By-vehicle fuel history        (VIEW_FUEL)

Analytics response:
GET /fuel/analytics → FuelAnalytics {
  total_entries, total_litres, total_cost,
  avg_cost_per_litre, avg_litres_per_fill,
  vehicles_tracked
}

Available to:
  SUPER_ADMIN, MANAGER, SUPERVISOR → full CRUD (MANAGE_FUEL)
  DRIVER                           → read-only (VIEW_FUEL)
```

---

### 12. Document Management (Phase 9)

```
POST /documents/
Permission: MANAGE_DOCUMENTS (MANAGER, SUPER_ADMIN)
Body: {
  category: DRIVER | VEHICLE | INSURANCE | PERMIT | OTHER,
  document_name,
  document_number (optional),
  vehicle_id (optional),
  driver_id (optional),
  issue_date (optional),
  expiry_date (optional),
  file_path (optional — placeholder for future S3/GCS),
  notes (optional)
}
Response: DocumentResponse { id, category, document_name, document_number,
           vehicle_id, driver_id, issue_date, expiry_date,
           is_expired, days_to_expiry,   ← computed server-side, not stored
           created_at, updated_at }

GET /documents/                     → List all documents            (VIEW_DOCUMENTS)
GET /documents/expiring?days=30     → Expiring within N days        (VIEW_DOCUMENTS)
GET /documents/{id}                 → Get single document           (VIEW_DOCUMENTS)
PUT /documents/{id}                 → Update metadata               (MANAGE_DOCUMENTS)
DELETE /documents/{id}              → Delete record                 (MANAGE_DOCUMENTS)

Expiry tracking:
  is_expired     = (expiry_date < today)
  days_to_expiry = (expiry_date - today).days  [negative if expired]

Available to:
  SUPER_ADMIN, MANAGER → full CRUD (MANAGE_DOCUMENTS)
  SUPERVISOR, DRIVER   → read-only (VIEW_DOCUMENTS)
```

---

### 13. Reports & CSV Export (Phase 9)

```
Permission: VIEW_REPORTS (SUPER_ADMIN, MANAGER only)
All endpoints return: StreamingResponse (no in-memory buffering)
Content-Disposition: attachment; filename="<report>.csv"

GET /reports/trips/csv
Query params: from_date (YYYY-MM-DD), to_date, status
Columns: id, vehicle_number, driver_name, route_label, trip_status,
         trip_date, start_km, end_km, revenue_amount, diesel_used,
         trip_advance, toll_expense, driver_bata, remarks

GET /reports/expenses/csv
Query params: from_date, to_date
Columns: id, trip_id, expense_type, amount, remarks, created_at

GET /reports/fuel/csv
Query params: from_date, to_date
Columns: id, vehicle_id, driver_id, trip_id, fuel_date, quantity_litres,
         cost_per_litre, total_cost, odometer_km, fuel_station

GET /reports/maintenance/csv
Query params: from_date, to_date
Columns: id, vehicle_id, maintenance_type, status, description,
         scheduled_date, completed_date, cost, vendor_name

GET /reports/attendance/csv
Query params: from_date, to_date
Columns: id, driver_id, shift_date, punch_in_time, punch_out_time,
         is_active, total_hours
```

---

## RBAC Permission Matrix (Route-Level)

| Endpoint | SUPER_ADMIN | MANAGER | SUPERVISOR | DRIVER |
|---|---|---|---|---|
| POST /companies/register | Public | Public | Public | Public |
| POST /auth/login | Public | Public | Public | Public |
| GET /auth/me | ✅ | ✅ | ✅ | ✅ |
| POST /vehicles/ | ✅ | ✅ | ❌ | ❌ |
| GET /vehicles/ | ✅ | ✅ | ✅ | ❌ |
| POST /drivers/ | ✅ | ✅ | ❌ | ❌ |
| GET /drivers/ | ✅ | ✅ | ✅ | ❌ |
| POST /routes/ | ✅ | ✅ | ❌ | ❌ |
| GET /routes/ | ✅ | ✅ | ✅ | ❌ |
| POST /allocations/ | ✅ | ✅ | ✅ | ❌ |
| POST /trips/ | ✅ | ✅ | ✅ | ❌ |
| GET /trips/ | ✅ | ✅ | ✅ | ✅ |
| PUT /trips/{id}/start | ✅ | ✅ | ✅ | ❌ |
| PUT /trips/{id}/complete | ✅ | ✅ | ✅ | ❌ |
| POST /trips/{id}/expenses | ✅ | ✅ | ✅ | ✅ |
| GET /dashboard/stats | ✅ | ✅ | ✅ | ✅ |
| POST /maintenance/ | ✅ | ✅ | ❌ | ❌ |
| GET /maintenance/ | ✅ | ✅ | ✅ | ❌ |
| GET /maintenance/{id} | ✅ | ✅ | ✅ | ❌ |
| PUT /maintenance/{id} | ✅ | ✅ | ❌ | ❌ |
| DELETE /maintenance/{id} | ✅ | ✅ | ❌ | ❌ |
| POST /fuel/ | ✅ | ✅ | ✅ | ❌ |
| GET /fuel/ | ✅ | ✅ | ✅ | ✅ |
| GET /fuel/analytics | ✅ | ✅ | ✅ | ✅ |
| PUT /fuel/{id} | ✅ | ✅ | ✅ | ❌ |
| DELETE /fuel/{id} | ✅ | ✅ | ✅ | ❌ |
| POST /documents/ | ✅ | ✅ | ❌ | ❌ |
| GET /documents/ | ✅ | ✅ | ✅ | ✅ |
| GET /documents/expiring | ✅ | ✅ | ✅ | ✅ |
| PUT /documents/{id} | ✅ | ✅ | ❌ | ❌ |
| DELETE /documents/{id} | ✅ | ✅ | ❌ | ❌ |
| GET /reports/trips/csv | ✅ | ✅ | ❌ | ❌ |
| GET /reports/expenses/csv | ✅ | ✅ | ❌ | ❌ |
| GET /reports/fuel/csv | ✅ | ✅ | ❌ | ❌ |
| GET /reports/maintenance/csv | ✅ | ✅ | ❌ | ❌ |
| GET /reports/attendance/csv | ✅ | ✅ | ❌ | ❌ |

---

## Common Error Responses

| Status | When |
|---|---|
| `400` | Invalid input (e.g., bad UUID format) |
| `401` | Missing/expired/invalid JWT |
| `403` | Valid JWT but insufficient permission |
| `404` | Resource not found (or not in tenant scope) |
| `409` | Conflict (duplicate, wrong status, etc.) |
| `422` | Pydantic validation failure |
| `500` | Unhandled server error |

---

## Trip Status Finite State Machine

```
          ┌──────────┐
          │  CREATED │
          └────┬─────┘
               │ PUT /trips/{id}/start
               ▼
          ┌──────────┐
          │  STARTED │
          └────┬─────┘
               │ PUT /trips/{id}/complete
               ▼
          ┌───────────┐
          │ COMPLETED │
          └───────────┘

CREATED ──► CANCELLED  (via PUT /trips/{id}/cancel)
STARTED, COMPLETED  ──► Cannot be cancelled
```
