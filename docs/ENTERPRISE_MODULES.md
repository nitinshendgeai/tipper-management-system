# Enterprise Module Roadmap — Tipper Management ERP

**Version:** 1.0.0  
**Last Updated:** 2026-05-19  
**Phase:** Phase 9 — Enterprise ERP Expansion  

---

## Overview

This document describes the enterprise module expansion strategy for Tipper Management ERP. The platform now serves as a scalable SaaS foundation. Each module below follows the same architectural patterns established in Phases 1–8:

- **Tenant isolation** — all data scoped by `company_id` from JWT
- **RBAC** — permission-gated endpoints using `require_permission()`
- **Idempotent bootstrap** — `repair_existing_schema()` handles column/index backfills
- **Performance-first** — GROUP BY aggregations, not N+1 loops
- **No binary storage** — documents store metadata only until cloud storage integration

---

## Module Status

| Module | Status | Phase | DB Tables | API Endpoints |
|---|---|---|---|---|
| Vehicle Master | ✅ Complete | Phase 1 | `master.vehicles` | CRUD |
| Driver Master | ✅ Complete | Phase 1 | `master.drivers` | CRUD |
| Route Master | ✅ Complete | Phase 1 | `master.routes` | CRUD |
| Shift Allocation | ✅ Complete | Phase 2 | `master.driver_vehicle_assignments` | CRUD |
| Trip Operations | ✅ Complete | Phase 2 | `operations.trips` | Lifecycle FSM |
| Trip Expenses | ✅ Complete | Phase 2 | `operations.trip_expenses` | CRUD |
| Driver Attendance | ✅ Complete | Phase 4 | `operations.attendance` | Punch-in/out |
| Analytics Engine | ✅ Complete | Phase 5 | (query-only) | KPIs, fleet, driver, alerts |
| Route Intelligence | ✅ Complete | Phase 5 | (stateless) | Google Maps + formula |
| **Maintenance Mgmt** | ✅ Phase 9 | Phase 9 | `operations.maintenance_logs` | CRUD + by-vehicle |
| **Fuel Management** | ✅ Phase 9 | Phase 9 | `operations.fuel_entries` | CRUD + analytics |
| **Document Mgmt** | ✅ Phase 9 | Phase 9 | `operations.documents` | CRUD + expiry |
| **Reports & Export** | ✅ Phase 9 | Phase 9 | (query-only) | 5 CSV endpoints |
| Vendor Management | 📋 Planned | Phase 10 | `master.vendors` | TBD |
| Payroll | 📋 Planned | Phase 10 | `operations.payroll` | TBD |
| GPS Tracking | 📋 Planned | Phase 11 | `operations.gps_events` | TBD |
| Invoice/Billing | 📋 Planned | Phase 10 | `operations.invoices` | TBD |
| Notifications | 📋 Planned | Phase 10 | (push/SMS) | TBD |
| Driver KYC | 📋 Planned | Phase 10 | (extends driver) | TBD |
| Tyre Management | 📋 Planned | Phase 10 | `operations.tyre_logs` | TBD |

---

## Phase 9 — Implemented Modules

### 1. Maintenance Management

**Purpose:** Track scheduled and completed vehicle maintenance events.

**DB Table:** `operations.maintenance_logs`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK | |
| `company_id` | UUID FK | → `tenant.companies.id` |
| `vehicle_id` | INTEGER FK | → `master.vehicles.id` |
| `maintenance_type` | VARCHAR(30) | ROUTINE \| REPAIR \| TYRE \| INSPECTION \| OTHER |
| `status` | VARCHAR(20) | SCHEDULED \| IN_PROGRESS \| COMPLETED \| CANCELLED |
| `description` | VARCHAR(500) | Required |
| `scheduled_date` | DATE | Optional |
| `completed_date` | DATE | Optional |
| `cost` | FLOAT | Optional |
| `odometer_km` | FLOAT | Optional |
| `vendor_name` | VARCHAR(200) | Optional |
| `notes` | VARCHAR(500) | Optional |
| `created_by_user_id` | INTEGER FK | Audit trail |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | Auto-updated |

**API Prefix:** `/maintenance/`  
**Permissions:** `MANAGE_MAINTENANCE` (write), `VIEW_MAINTENANCE` (read)  
**Roles with access:** SUPER_ADMIN, MANAGER (full), SUPERVISOR (view only)

**Status FSM:** SCHEDULED → IN_PROGRESS → COMPLETED / CANCELLED

**Indexes:** `company_id`, `vehicle_id`, `(company_id, status)`, `(company_id, maintenance_type)`

---

### 2. Fuel Management

**Purpose:** Track every fuel fill-up per vehicle. Support cost tracking, mileage analytics.

**DB Table:** `operations.fuel_entries`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK | |
| `company_id` | UUID FK | → `tenant.companies.id` |
| `vehicle_id` | INTEGER FK | → `master.vehicles.id` |
| `driver_id` | INTEGER FK | → `master.drivers.id` (optional) |
| `trip_id` | INTEGER FK | → `operations.trips.id` (optional) |
| `fuel_date` | DATE | Required |
| `quantity_litres` | FLOAT | Required, > 0 |
| `cost_per_litre` | FLOAT | Optional |
| `total_cost` | FLOAT | Auto-computed or manual |
| `odometer_km` | FLOAT | For mileage analytics |
| `fuel_station` | VARCHAR(200) | Optional |
| `notes` | VARCHAR(500) | Optional |
| `created_by_user_id` | INTEGER FK | Audit trail |
| `created_at` | DATETIME | |

**API Prefix:** `/fuel/`  
**Permissions:** `MANAGE_FUEL` (write), `VIEW_FUEL` (read)  
**Roles with access:** SUPER_ADMIN, MANAGER (full), SUPERVISOR (full), DRIVER (view)

**Analytics endpoint:** `GET /fuel/analytics` — aggregate totals, avg cost/litre, vehicles tracked.

**Indexes:** `company_id`, `vehicle_id`, `(company_id, vehicle_id)`, `fuel_date`

**Future:** Fuel efficiency anomaly detection, cost trends, per-vehicle efficiency graphs.

---

### 3. Document Management

**Purpose:** Track metadata for driver, vehicle, insurance, and permit documents with expiry alerts.

**DB Table:** `operations.documents`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK | |
| `company_id` | UUID FK | → `tenant.companies.id` |
| `category` | VARCHAR(30) | DRIVER \| VEHICLE \| INSURANCE \| PERMIT \| OTHER |
| `document_name` | VARCHAR(200) | e.g., "Driver License", "Insurance Policy" |
| `document_number` | VARCHAR(100) | Optional (license no, policy no) |
| `vehicle_id` | INTEGER FK | Optional — links to a vehicle |
| `driver_id` | INTEGER FK | Optional — links to a driver |
| `issue_date` | DATE | Optional |
| `expiry_date` | DATE | Optional — indexed for expiry queries |
| `file_path` | VARCHAR(500) | Placeholder for future S3/GCS integration |
| `notes` | VARCHAR(500) | Optional |
| `created_by_user_id` | INTEGER FK | Audit trail |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | Auto-updated |

**API Prefix:** `/documents/`  
**Permissions:** `MANAGE_DOCUMENTS` (write), `VIEW_DOCUMENTS` (read)  
**Roles with access:** SUPER_ADMIN, MANAGER (full), SUPERVISOR (view), DRIVER (view)

**Special endpoint:** `GET /documents/expiring?days=30` — documents expiring within N days.  
**Computed fields:** `is_expired`, `days_to_expiry` (calculated server-side, not stored).

**Indexes:** `company_id`, `expiry_date`, `(company_id, category)`, `vehicle_id`, `driver_id`

**Future:** File upload to S3/GCS, reminder notifications, automated expiry alerts.

---

### 4. Reports & CSV Export

**Purpose:** Downloadable CSV reports for all operational data.

**API Prefix:** `/reports/`  
**Permission:** `VIEW_REPORTS` (SUPER_ADMIN, MANAGER only)

| Endpoint | Description | Filters |
|---|---|---|
| `GET /reports/trips/csv` | All trip data | `from_date`, `to_date`, `status` |
| `GET /reports/expenses/csv` | Trip expenses | `from_date`, `to_date` |
| `GET /reports/fuel/csv` | Fuel entries | `from_date`, `to_date` |
| `GET /reports/maintenance/csv` | Maintenance logs | `from_date`, `to_date` |
| `GET /reports/attendance/csv` | Driver attendance | `from_date`, `to_date` |

All CSV responses use `StreamingResponse` — no in-memory buffering of large datasets.  
Content-Disposition: `attachment; filename="<report>.csv"`.

---

## Phase 10 — Planned Modules

### Vendor Management

**Purpose:** Track garages, fuel stations, tyre vendors, spare parts suppliers.

**Planned DB:** `master.vendors`

| Column | Notes |
|---|---|
| `company_id` | Tenant-scoped |
| `vendor_name` | |
| `vendor_type` | GARAGE \| FUEL_STATION \| TYRE \| PARTS \| OTHER |
| `contact_name` | |
| `mobile_number` | |
| `address` | |
| `gst_number` | |

**Linkage:** `maintenance_logs.vendor_id → master.vendors.id`

**Future RBAC:** `MANAGE_VENDORS`, `VIEW_VENDORS` → MANAGER+

---

### Driver Payroll Foundation

**Purpose:** Track driver salary, daily allowances, trip incentives, deductions.

**Planned DB:** `operations.payroll_entries`

| Column | Notes |
|---|---|
| `company_id` | Tenant-scoped |
| `driver_id` | FK |
| `pay_period_start` | Date |
| `pay_period_end` | Date |
| `base_salary` | Float |
| `trip_incentive` | Float (based on trips completed) |
| `advance_deduction` | Float |
| `net_payable` | Float |

**Future RBAC:** `MANAGE_PAYROLL`, `VIEW_PAYROLL` → MANAGER+ (no SUPERVISOR access)

---

### Tyre Management

**Purpose:** Track tyre installation, removal, condition, and life.

**Planned DB:** `operations.tyre_logs`

| Column | Notes |
|---|---|
| `company_id` | Tenant-scoped |
| `vehicle_id` | FK |
| `tyre_position` | FL, FR, RL, RR, SPARE, etc. |
| `brand` | |
| `serial_number` | |
| `installed_date` | |
| `removed_date` | Optional |
| `odometer_at_install` | Float |
| `odometer_at_removal` | Float |
| `removal_reason` | WORN \| PUNCTURE \| BURST \| OTHER |

---

### Invoice / Billing

**Purpose:** Generate customer invoices based on completed trips.

**Planned DB:** `operations.invoices`, `operations.invoice_items`

**Linkage:** `invoice_items.trip_id → operations.trips.id`

**Future:** PDF invoice generation via ReportLab / WeasyPrint.

---

### Notifications Architecture

**Current:** Alert detection already exists via `alert_service.py` (stateless detectors).

**Phase 10 plan:**
- `operations.notification_queue` table for pending notifications
- Background scheduler checks for: expiring documents, overdue maintenance, low attendance
- Push delivery: Firebase FCM for mobile (Flutter)
- Future: Email via SendGrid, SMS via Twilio

**No external integrations yet** — architecture only.

---

## Enterprise RBAC Expansion

### Current Role Hierarchy

```
SUPER_ADMIN  →  Full access (all 25 permissions)
MANAGER      →  Operational management (22 permissions)
SUPERVISOR   →  Trip lifecycle + field operations (14 permissions)
DRIVER       →  Self-service only (6 permissions)
```

### Phase 10 Planned Roles

| Role | Purpose | Base From |
|---|---|---|
| `ACCOUNTS` | Invoice, billing, financial reports | MANAGER subset |
| `HR` | Driver onboarding, KYC, payroll | MANAGER subset |
| `MAINTENANCE_SUPERVISOR` | Maintenance management, vendor liaison | SUPERVISOR + MANAGE_MAINTENANCE |
| `FUEL_MANAGER` | Fuel entries, fuel analytics | SUPERVISOR + MANAGE_FUEL |
| `FLEET_MANAGER` | Vehicle master, maintenance, documents | MANAGER minus payroll |

**Implementation note:** New roles are added to `ROLE_PERMISSIONS` dict in `permissions.py`. No schema changes needed — permissions are stored as JSON arrays in `tenant.user_roles`.

---

## Scalability Notes

### DB Growth Projections

| Table | Rows/month (50 vehicles) | Index Strategy |
|---|---|---|
| `operations.trips` | ~2,500 | `(company_id, trip_date)`, `(company_id, trip_status)` |
| `operations.fuel_entries` | ~200 | `(company_id, vehicle_id)`, `fuel_date` |
| `operations.maintenance_logs` | ~50 | `(company_id, status)` |
| `operations.attendance` | ~1,500 | `(shift_date)`, `(driver_id, shift_date)` |
| `operations.documents` | ~20 (one-time) | `expiry_date`, `category` |

**Current indexes** cover all high-frequency query patterns. No sharding needed until ~100M rows.

### API Scaling

- All reads are O(1) with proper indexes — no table scans
- Dashboard: 7 queries (was 21) after Phase 9 GROUP BY consolidation
- Analytics: GROUP BY aggregations — single pass per query
- CSV exports: `StreamingResponse` — no in-memory dataset buffering

### Frontend Scalability

- Single API call per tab (trip_screen: 4 tabs → 1 call, Phase 8 fix)
- All screens use shared `DioClient.instance` with 401 interceptor
- Pagination not yet implemented — add `?page=&limit=` when list sizes exceed 500

---

## Client Onboarding Checklist

New transport company onboarding flow:

1. **Register** — `POST /companies/register` (public endpoint)
   - Creates: company, settings, 4 user roles, admin user
   - Admin credentials: `admin@<slug>.com` / `admin1234` (must change on first login)

2. **Login** — `POST /auth/login` with `company_slug`
   - Returns JWT with `company_id`, `role_name`, `user_id`

3. **Add vehicles** — `POST /vehicles/` (MANAGER+)

4. **Add drivers** — `POST /drivers/` (MANAGER+)

5. **Create routes** — `POST /routes/` (MANAGER+)

6. **Allocate drivers to vehicles** — `POST /allocations/` (SUPERVISOR+)

7. **Begin operations** — `POST /trips/` → start → complete (SUPERVISOR+)

8. **Track documents** — `POST /documents/` (MANAGER+)

9. **Log fuel** — `POST /fuel/` (SUPERVISOR+)

10. **Schedule maintenance** — `POST /maintenance/` (MANAGER+)

11. **Export reports** — `GET /reports/trips/csv` etc. (MANAGER+)

**Known gaps:**
- `admin1234` default password — no forced change on first login (AUTH-004, Phase 10 backlog)
- No user invitation/management API yet (GAP-006, Phase 10)
- Subscription limits not enforced (GAP-005, Phase 10)
