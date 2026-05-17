# System Architecture — Tipper Management ERP

**Version:** 2.0.0  
**Last Updated:** 2026-05-17  
**Phase:** System Stabilization  
**Status:** Production-deployed (Railway)

---

## Overview

Tipper Management ERP is a multi-tenant SaaS platform for managing tipper truck fleets. It serves transport companies as isolated tenants, each operating their own fleet of vehicles, drivers, routes, and trips.

---

## Technology Stack

| Layer | Technology | Version |
|---|---|---|
| Backend API | FastAPI | 0.128.8 |
| ASGI Server | Uvicorn | 0.39.0 |
| ORM | SQLAlchemy | 2.0.49 |
| Migrations | Alembic | 1.16.5 |
| Database | PostgreSQL | (Railway-managed) |
| DB Driver | psycopg2-binary | 2.9.12 |
| Auth | JWT (python-jose) | 3.5.0 |
| Password Hashing | passlib + bcrypt | 1.7.4 / 4.0.1 |
| Frontend | Flutter | Latest stable |
| HTTP Client (Flutter) | Dio | ^5.9.2 |
| State Management | Provider | ^6.1.5+1 |
| Navigation | go_router | ^17.2.3 |
| Secure Storage | flutter_secure_storage | ^10.1.0 |
| Deployment | Railway.io | NIXPACKS builder |

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter Frontend                           │
│          (iOS / Android / macOS / Windows / Linux / Web)        │
│                                                                 │
│   Dio HTTP Client → Authorization: Bearer <JWT>                 │
│   flutter_secure_storage → Token storage                        │
│   Provider → State management                                   │
│   go_router → Navigation                                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │ HTTPS
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│           FastAPI Backend (Railway — tipper-management-system)  │
│                                                                 │
│  ┌──────────┐  ┌─────────────────┐  ┌──────────────────────┐  │
│  │  CORS    │  │  JWT Middleware  │  │  TenantContext (CV)  │  │
│  │ (*)      │  │  HTTPBearer     │  │  contextvars         │  │
│  └──────────┘  └─────────────────┘  └──────────────────────┘  │
│                                                                 │
│  ┌─────────┐ ┌──────────┐ ┌────────┐ ┌──────────┐ ┌────────┐ │
│  │  Auth   │ │ Company  │ │Vehicle │ │  Driver  │ │ Route  │ │
│  │ Router  │ │ Router   │ │ Router │ │  Router  │ │ Router │ │
│  └─────────┘ └──────────┘ └────────┘ └──────────┘ └────────┘ │
│                                                                 │
│  ┌──────────────┐ ┌──────────────────┐ ┌───────────────────┐  │
│  │  Allocation  │ │ Route Intelligence│ │  Trip + Expense  │  │
│  │   Router     │ │  Router (Maps AI) │ │  Routers         │  │
│  └──────────────┘ └──────────────────┘ └───────────────────┘  │
│                                                                 │
│  ┌────────────────────┐  ┌──────────────────────────────────┐  │
│  │  Dashboard Router  │  │  Admin Router (legacy)           │  │
│  └────────────────────┘  └──────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  SQLAlchemy ORM — 4 PostgreSQL Schemas                  │  │
│  │  auth | master | operations | tenant                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────────┘
                            │ postgresql://
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   PostgreSQL (Railway-managed)                   │
│                                                                 │
│  Schema: auth       → roles, users                              │
│  Schema: tenant     → companies, company_settings, user_roles   │
│  Schema: master     → vehicles, drivers, routes, assignments    │
│  Schema: operations → trips, trip_expenses                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Database Schema Design

### Schema: `auth`
Legacy single-tenant schema. Still active due to incomplete migration.

| Table | Purpose |
|---|---|
| `auth.roles` | Legacy role definitions (Admin, Manager, Dispatcher, Driver, Accounts) |
| `auth.users` | All users — now carries both `role_id` (legacy) and `company_id` + `user_role_id` (multi-tenant) |

### Schema: `tenant`
Multi-tenant company management.

| Table | Purpose |
|---|---|
| `tenant.companies` | One row per company (UUID pk) |
| `tenant.company_settings` | Per-company limits and subscription tier |
| `tenant.user_roles` | Per-company RBAC roles with JSON permission arrays |

### Schema: `master`
Operational master data — all rows scoped by `company_id`.

| Table | Purpose |
|---|---|
| `master.vehicles` | Fleet inventory with status tracking |
| `master.drivers` | Driver registry with status tracking |
| `master.routes` | Predefined route templates |
| `master.driver_vehicle_assignments` | Shift-based driver-to-vehicle bindings |

### Schema: `operations`
Live operational records — all rows scoped by `company_id`.

| Table | Purpose |
|---|---|
| `operations.trips` | Full trip lifecycle (CREATED → STARTED → COMPLETED/CANCELLED) |
| `operations.trip_expenses` | Itemized expenses per trip |

---

## Authentication Flow

```
Client                          FastAPI Backend
  │                                    │
  │  POST /auth/login                  │
  │  { email, password }               │
  │ ─────────────────────────────────► │
  │                                    │ 1. Lookup user by email (auth.users)
  │                                    │    ⚠ No company_id filter (known issue)
  │                                    │ 2. verify_password() — bcrypt
  │                                    │ 3. Resolve role_name via user_role_id
  │                                    │    → tenant.user_roles
  │                                    │ 4. Create JWT:
  │                                    │    { sub, role_id, role_name, company_id }
  │  { access_token, token_type }      │
  │ ◄───────────────────────────────── │
  │                                    │
  │  GET /any-protected-route          │
  │  Authorization: Bearer <token>     │
  │ ─────────────────────────────────► │
  │                                    │ 1. HTTPBearer extracts token
  │                                    │ 2. jwt.decode() → payload
  │                                    │ 3. extract_tenant_from_token()
  │                                    │    → company_id, email, role_name
  │                                    │ 4. TenantContext.set_*(...)
  │                                    │ 5. DB query: User where
  │                                    │    email=email AND company_id=cid
  │                                    │ 6. require_permission() check
  │                                    │ 7. filter_by_company() on all queries
  │  Response data (company-scoped)    │
  │ ◄───────────────────────────────── │
```

---

## Startup Lifecycle

```
Railway starts uvicorn
       │
       ▼
FastAPI app initializes
       │
       ▼
@app.on_event("startup")
       │
       ├─ Base.metadata.create_all(bind=engine)
       │   Creates tables for all registered models
       │
       └─ seed_data()
           Creates legacy auth.roles (5 roles)
           Creates admin@tipper.com user (legacy, no company_id)
```

> **Note:** `ensure_database_schemas()` and `repair_existing_schema()` are imported in `main.py` but not called from startup. This is a known issue — see `docs/KNOWN_ISSUES.md`.

---

## Multi-Tenancy Design

### Isolation Mechanism
- Every data table has a `company_id UUID FK → tenant.companies.id`
- All authenticated requests have `company_id` extracted from the JWT
- `TenantContext` (Python `contextvars`) holds the per-request `company_id`
- All data queries go through `filter_by_company(query, Model)` which appends `WHERE company_id = <current>`

### Tenant Lifecycle
1. Company registers via `POST /companies/register` (public endpoint)
2. System auto-creates: Company → Settings → 4 UserRoles → admin user
3. Admin logs in and manages fleet under their isolated namespace
4. All data writes automatically tag `company_id = current_user.company_id`

---

## API Dependency Chain

```
HTTPBearer (token extraction)
    │
    ▼
extract_tenant_from_token(token)
    │  → company_id, email, role_name
    ▼
TenantContext.set_*(...)          [contextvars — async-safe]
    │
    ▼
DB lookup: User WHERE email=? AND company_id=?
    │
    ▼
get_current_tenant_user() → User ORM object
    │
    ▼
require_permission(Permission.X)
    │  → check_permission(role_name, Permission.X)
    ▼
Route handler executes
    │
    └─ filter_by_company(query, Model)
           → all queries scoped to company_id
```

---

## Deployment Architecture

```
GitHub (main branch)
    │
    ▼ auto-deploy on push
Railway.io
    │  Builder: NIXPACKS
    │  Start:   cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
    │  Health:  GET /docs (Swagger UI)
    │  Restart: ON_FAILURE
    │
    ├── FastAPI App
    └── PostgreSQL (Railway-managed database)
         DATABASE_URL injected via Railway environment variable
```

---

## External Integrations

| Service | Usage | Fallback |
|---|---|---|
| Google Maps Distance Matrix API | Route distance, duration calculation | Formula-based estimate |
| Railway PostgreSQL | Primary database | None |

---

## Key Environment Variables

| Variable | Required | Default | Notes |
|---|---|---|---|
| `DATABASE_URL` | ✅ Yes | None (raises RuntimeError) | Auto-converted from `postgres://` to `postgresql://` |
| `SECRET_KEY` | ✅ Yes (prod) | `tipper-secret-key` | ⚠ Weak default — must be set in production |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | `60` | JWT expiry duration |
| `GOOGLE_MAPS_API_KEY` | No | `""` | Falls back to formula if missing |
| `TIPPER_FUEL_EFFICIENCY_KM_PER_LITRE` | No | `5.0` | Used in diesel estimates |
