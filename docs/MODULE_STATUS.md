# Module Status — Tipper Management ERP

**Version:** 11.0.0
**Last Updated:** 2026-05-20
**Phase:** Phase 11 — Security Hardening + SaaS Maturity

---

## Backend Modules

| Module | Router | Status | Phase |
|---|---|---|---|
| Authentication | `/auth` | ✅ Production | 1 |
| Change Password | `/auth/change-password` | ✅ Production | 11 |
| Company Registration | `/companies` | ✅ Production | 1 |
| Vehicle Master | `/vehicles` | ✅ Production | 2 |
| Driver Master | `/drivers` | ✅ Production | 2 |
| Route Master | `/routes` | ✅ Production | 2 |
| Shift Allocation | `/allocations` | ✅ Production | 3 |
| Trip Operations | `/trips` | ✅ Production | 3 |
| Trip Expenses | `/trips/{id}/expenses` | ✅ Production | 3 |
| Driver Attendance | `/attendance` | ✅ Production | 4 |
| Dashboard Analytics | `/dashboard` | ✅ Production | 5 |
| Operational Analytics | `/analytics` | ✅ Production | 5 |
| Route Intelligence | `/route-intelligence` | ✅ Production | 5 |
| Reports & Export | `/reports` | ✅ Production | 9 |
| Maintenance Management | `/maintenance` | ✅ Production | 9 |
| Fuel Management | `/fuel` | ✅ Production | 9 |
| Document Management | `/documents` | ✅ Production | 9 |
| User Management | `/users` | ✅ Production | 10 |
| Automation Status | `/automation/status` | ✅ Production | 10 |

---

## Frontend Modules

| Module | Screen | Status | Phase |
|---|---|---|---|
| Authentication | LoginScreen | ✅ Production | 1 |
| Change Password | ChangePasswordScreen | ✅ Production | 11 |
| Dashboard | DashboardScreen | ✅ Production | 5 |
| Vehicles | VehicleScreen | ✅ Production | 2 |
| Drivers | DriverScreen | ✅ Production | 2 |
| Routes | RouteScreen | ✅ Production | 2 |
| Trips | TripScreen | ✅ Production | 3 |
| Shift Allocation | AllocationScreen | ✅ Production | 3 |
| Attendance | AttendanceScreen | ✅ Production | 4 |
| Maintenance | MaintenanceScreen | ✅ Production | 10 |
| Fuel | FuelScreen | ✅ Production | 10 |
| Documents | DocumentScreen | ✅ Production | 10 |
| Users | UserScreen | ✅ Production | 11 |

---

## Security Status

| Feature | Status |
|---|---|
| JWT authentication | ✅ HS256, 60min expiry |
| CORS lockdown | ✅ Origin whitelist via env var |
| Login rate limiting | ✅ 10/IP/60s in-memory |
| Forced password change | ✅ On first login |
| Subscription limits | ✅ Enforced on vehicle/user create |
| Tenant isolation | ✅ filter_by_company() on all queries |
| RBAC | ✅ 4 roles, 25+ permissions |
| SECRET_KEY | ⚠️ Must be set in Railway env |

---

## Background Services

| Service | Description | Status |
|---|---|---|
| DB Init Thread | Schema + table creation on startup | ✅ Production |
| Automation Scheduler | Vehicle/driver sync every 5 min | ✅ Production |
| Alert Service | On-demand operational alerts (8 types) | ✅ Production |
| Analytics Service | KPI aggregation queries | ✅ Production |
