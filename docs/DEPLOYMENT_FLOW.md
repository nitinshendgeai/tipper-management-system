# Deployment Flow — Tipper Management ERP

**Version:** 3.0.0
**Last Updated:** 2026-05-19
**Platform:** Railway.io
**Production Backend:** `https://tipper-management-system.up.railway.app`
**Production Frontend:** `https://tipper-frontend-ar.up.railway.app`

---

## Infrastructure Overview

```
GitHub Repository (staging-release branch)
    │ (push triggers auto-build)
    │
    ▼
Railway.io
    ├── FastAPI Service (NIXPACKS auto-build)
    │     Start: cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
    │     Health: GET /health   ← zero DB calls, responds <1ms
    │     Restart: ON_FAILURE
    │
    └── PostgreSQL Service (Railway-managed)
          Connection via: DATABASE_URL env variable
```

---

## Railway Configuration (`railway.toml`)

```toml
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT"
healthcheckPath = "/health"       # Phase 6: was /docs — DB-free, responds in <1ms
healthcheckTimeout = 120          # Phase 6: was 300 — reduced because /health is instant
restartPolicyType = "ON_FAILURE"
```

---

## Environment Variables (Required on Railway)

| Variable | Value | Notes |
|---|---|---|
| `DATABASE_URL` | `postgresql://...` | Auto-injected by Railway if PostgreSQL plugin is connected |
| `SECRET_KEY` | Random 32+ char string | ⚠️ Must be set — default `"tipper-secret-key"` is insecure |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | JWT TTL (optional, defaults to 60) |
| `GOOGLE_MAPS_API_KEY` | Google Maps API key | Optional — route intelligence falls back to formula without it |
| `TIPPER_FUEL_EFFICIENCY_KM_PER_LITRE` | `5.0` | Optional — tipper fleet diesel efficiency |

---

## Zero-DB Startup Design (Phase 6)

**Root cause of past failures:** any DB call in `startup()` raised `OperationalError`
if Postgres wasn't ready on cold-start. The process crashed before serving a single
request — Railway saw "service unavailable".

**Solution:** startup event does zero database work. All 4 init steps run in a daemon
background thread after the process is already healthy and serving requests.

```
Uvicorn process starts
    │
    ▼
GET /health registered — responds 200 immediately
    │
    ▼
@app.on_event("startup") fires
    └─► launches daemon thread "db-init" — returns immediately (no DB work)
    │
    ▼
Railway healthcheck: GET /health → 200 in <1ms ✅ DEPLOY SUCCEEDS
    │
    ▼  (background — concurrent with live traffic)
_run_background_init():
    ├── 1/4 ensure_database_schemas()   CREATE SCHEMA IF NOT EXISTS ×4
    ├── 2/4 Base.metadata.create_all()  CREATE TABLE IF NOT EXISTS ×N
    ├── 3/4 repair_existing_schema()    ALTER TABLE + CREATE INDEX + DO blocks
    └── 4/4 seed_data()                 Legacy roles + admin@tipper.com
```

Monitor background init via `/health`:
```json
{
  "status": "ok",
  "db_init_complete": true,
  "db_init_error": null,
  "db_init_steps_done": ["schemas", "tables", "repair_schema", "seed_data"],
  "db_init_elapsed_s": 4.2
}
```

---

## repair_existing_schema() — Why It Exists

`Base.metadata.create_all()` never modifies existing tables. Pre-existing databases
need `repair_existing_schema()` to backfill missing columns and add indexes:

| What | SQL |
|---|---|
| `company_id` column on all 7 tenant tables | `ALTER TABLE ... ADD COLUMN IF NOT EXISTS company_id UUID` |
| 15 performance indexes | `CREATE INDEX IF NOT EXISTS idx_*` |
| Per-company unique constraints | `DO $$ ... IF NOT EXISTS ... $$` blocks |

---

## Standalone DB Init Script

For manual execution after a fresh DB reset or Railway one-off job:

```bash
cd backend && python scripts/run_db_init.py
```

Runs all 4 steps with per-step timing. Fully idempotent.

---

## Database Migrations (Alembic)

```bash
cd backend
alembic current          # check state
alembic upgrade head     # apply pending migrations
alembic downgrade -1     # roll back one step
```

Migration files: `backend/alembic/versions/`

---

## Rollback Procedure

```
Railway dashboard → Deployments → select previous → Redeploy
```

For DB rollback: `cd backend && alembic downgrade <revision>`

---

## Monitoring

| Check | URL |
|---|---|
| Health + DB init progress | `GET .../health` |
| Swagger UI | `GET .../docs` |
| Railway logs | Dashboard → Logs tab → look for `[bg-init]` lines |

---

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| "service unavailable" on healthcheck | Old startup with DB calls | Phase 6 zero-DB fix resolves this |
| `db_init_error` in /health | DB unreachable during background init | Check Postgres plugin; run `run_db_init.py` |
| `column "company_id" does not exist` | Old DB missing backfill | Phase 7 fix in `repair_existing_schema()` — redeploy |
| `RuntimeError: DATABASE_URL is required` | Env var not set | Set in Railway Variables |
| Login fails, weird JWT errors | Weak default SECRET_KEY | Set `SECRET_KEY` in Railway Variables |
| SUPERVISOR 403 on start/complete trip | RBAC-007 — missing MANAGE_TRIPS | Fixed Phase 7 — redeploy |
| `/route-intelligence/calculate` 403 | SEC-002 fix — now requires auth | Client must send Bearer token |
