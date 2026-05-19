# Deployment Flow — Tipper Management ERP

**Version:** 2.0.0  
**Last Updated:** 2026-05-17  
**Platform:** Railway.io  
**Production URL:** `https://tipper-management-system.up.railway.app`

---

## Infrastructure Overview

```
GitHub Repository
    │ (push to main branch)
    │
    ▼
Railway.io
    ├── FastAPI Service (NIXPACKS auto-build)
    │     Start: cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
    │     Health: GET /docs
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
healthcheckPath = "/docs"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
```

**NIXPACKS** auto-detects Python, installs from `backend/requirements.txt`, and runs the start command.

---

## Environment Variables (Required on Railway)

Set these in Railway → Project → Variables:

| Variable | Value | Notes |
|---|---|---|
| `DATABASE_URL` | `postgresql://...` (auto-injected by Railway) | Railway auto-sets this if PostgreSQL plugin is connected |
| `SECRET_KEY` | Random 32+ char string | ⚠️ Must be set — default is insecure |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | JWT TTL (optional, defaults to 60) |
| `GOOGLE_MAPS_API_KEY` | Google Maps API key | Optional — route intelligence falls back to formula without it |
| `TIPPER_FUEL_EFFICIENCY_KM_PER_LITRE` | `5.0` | Optional — tipper fleet diesel efficiency |

---

## Deploy Process

### Standard Deploy (Code Push)

```
1. Developer pushes to main branch
2. Railway detects push → triggers auto-build
3. NIXPACKS:
   a. Detects Python project
   b. Installs dependencies: pip install -r backend/requirements.txt
   c. Runs start command
4. Uvicorn starts on $PORT
5. FastAPI startup event fires:
   a. Base.metadata.create_all(bind=engine)   ← creates any missing tables
   b. seed_data()                              ← seeds legacy roles + admin user
6. Railway polls GET /docs
7. If /docs returns 200 within 300s → deploy successful
8. Traffic switched to new instance
```

### On Startup Failure

```
Railway policy: restartPolicyType = "ON_FAILURE"
→ Automatic restart on crash
→ Check Railway logs if healthcheck fails repeatedly
```

---

## Database Migration Process

Migrations use **Alembic**. Run from `backend/` directory.

### Running a Migration (Manual)

```bash
cd backend

# Check current migration state
alembic current

# Show migration history
alembic history --verbose

# Apply all pending migrations
alembic upgrade head

# Roll back one step
alembic downgrade -1
```

### Creating a New Migration

```bash
# Auto-generate from model changes (review before applying!)
alembic revision --autogenerate -m "describe_your_change"

# Or create a blank migration
alembic revision -m "describe_your_change"
```

### Migration Files Location

```
backend/alembic/versions/
├── 6c49d61bb804_initial_migration.py      ← Initial schema
├── ee2c2b6b204c_update_routes_table.py    ← Routes update
├── 64e866bd0f40_add_remarks_to_routes.py  ← Remarks column
└── a1b2c3d4e5f6_add_multi_tenant_support.py ← Multi-tenant transform
```

### Migration vs. `Base.metadata.create_all`

**Important:** The app uses **both** mechanisms:
- `Base.metadata.create_all()` runs on startup — safe for adding new tables but does NOT modify existing tables
- Alembic migrations handle column changes, index changes, and constraint changes

When adding a new model, add it to `app/models/__init__.py` so `Base.metadata.create_all()` picks it up.

---

## Startup Sequence (After Phase 2 Fix)

```
Uvicorn process starts
    │
    ▼
FastAPI app initialized
    │  (imports all routers, models)
    │
    ▼
@app.on_event("startup") fires
    │
    ├─► ensure_database_schemas(engine)
    │       CREATE SCHEMA IF NOT EXISTS auth
    │       CREATE SCHEMA IF NOT EXISTS master
    │       CREATE SCHEMA IF NOT EXISTS operations
    │       CREATE SCHEMA IF NOT EXISTS tenant
    │
    ├─► Base.metadata.create_all(bind=engine)
    │       Creates tables (schemas now guaranteed to exist)
    │
    ├─► repair_existing_schema(engine)
    │       Runs IF NOT EXISTS column repairs (safe on existing DBs)
    │
    └─► seed_data()
            Checks/creates auth.roles (5 legacy roles)
            Checks/creates admin@tipper.com user
            Commits and closes session
    │
    ▼
FastAPI ready — routes active
    │
    ▼
Railway health check: GET /docs → 200
    │
    ▼
Deploy complete — traffic routed
```

---

## Rollback Procedure

```
1. In Railway dashboard → Deployments
2. Select previous successful deployment
3. Click "Redeploy" to restore previous version

For database rollbacks:
  cd backend
  alembic downgrade <target-revision>
  ⚠ Warning: downgrade may lose data — verify migration has a safe down() function
```

---

## Monitoring

| Check | Method |
|---|---|
| App health | `GET https://tipper-management-system.up.railway.app/docs` |
| API schema | `GET https://tipper-management-system.up.railway.app/openapi.json` |
| Railway logs | Railway dashboard → Logs tab |
| DB connection | Any authenticated API call will fail if DB is unreachable |

---

## Common Deployment Issues

| Issue | Likely Cause | Fix |
|---|---|---|
| Health check fails (timeout) | App crashing on startup (usually DB connection) | Check Railway logs; verify DATABASE_URL is set |
| `RuntimeError: DATABASE_URL is required` | DATABASE_URL env var not set | Set in Railway Variables |
| `sqlalchemy.exc.OperationalError` | Schema doesn't exist on fresh DB | Phase 2 fix (START-001) ensures schemas created first |
| App starts but login fails | SECRET_KEY not set (using insecure default) | Set SECRET_KEY in Railway Variables |
| Migration fails | Conflict between `create_all` and Alembic | Run `alembic current` and `alembic upgrade head` to sync |
