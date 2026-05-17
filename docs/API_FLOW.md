# API Flow — Tipper Management ERP

**Version:** 2.0.0  
**Last Updated:** 2026-05-17  
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
Permission: MANAGE_VEHICLES (or similar)

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
Body: { source_location, destination_location }

Response: {
  source_location,
  destination_location,
  distance_km,
  duration_minutes,
  estimated_diesel_litres,
  source: "google_maps" | "formula_estimate"
}

No auth required on this endpoint (public).
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

  trips_total, trips_created, trips_active, trips_completed, trips_cancelled,

  total_revenue,        ← sum of completed trip revenue_amount
  total_diesel_used,    ← sum of completed trip diesel_used
  total_trip_expenses,  ← sum of all trip_expenses.amount

  utilisation_pct       ← (on_trip / active_fleet) * 100
}
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
| POST /allocations/ | ✅ | ✅ | ❌ | ❌ |
| POST /trips/ | ✅ | ✅ | ✅ | ❌ |
| GET /trips/ | ✅ | ✅ | ✅ | ✅ |
| PUT /trips/{id}/start | ✅ | ✅ | ✅ | ❌ |
| PUT /trips/{id}/complete | ✅ | ✅ | ✅ | ❌ |
| POST /trips/{id}/expenses | ✅ | ✅ | ✅ | ✅ |
| GET /dashboard/stats | ✅ | ✅ | ✅ | ✅ |

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
