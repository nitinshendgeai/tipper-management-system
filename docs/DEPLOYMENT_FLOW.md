# Deployment Flow — Tipper Management ERP

**Version:** 10.0.0
**Last Updated:** 2026-05-20

---

## Architecture

```
GitHub (staging-release branch)
    ↓ push
Railway auto-build
    ├── Backend Service  → https://tipper-management-system-ar.up.railway.app
    └── Frontend Service → https://tipper-frontend-ar.up.railway.app
```

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `staging-release` | Live deployment — Railway watches this branch |
| `main` | Stable reviewed code — merge from staging after testing |

**All changes go to `staging-release` first.**

---

## Backend Startup Lifecycle

```
uvicorn starts
    ↓
/health endpoint available immediately (zero DB work)
    ↓
Background thread 1 — db-init (30s)
    1. ensure_database_schemas()   — CREATE SCHEMA IF NOT EXISTS ×4
    2. Base.metadata.create_all()  — CREATE TABLE IF NOT EXISTS ×N
    3. repair_existing_schema()    — ALTER TABLE + CREATE INDEX
    4. seed_data()                 — legacy roles + admin user
    ↓
Background thread 2 — automation-scheduler (starts after 30s delay)
    Every 5 minutes:
    - Sync vehicle availability
    - Sync driver availability
    - Log overdue trips
```

**Railway healthcheck:** `GET /health` — always returns 200, never blocks on DB.

---

## Environment Variables

### Backend (required)
| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string (set by Railway) |
| `SECRET_KEY` | JWT signing secret — **must be set manually** |

### Backend (optional)
| Variable | Default | Description |
|---|---|---|
| `ALLOWED_ORIGINS` | Railway frontend URL | Comma-separated CORS origins |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | JWT expiry |
| `GOOGLE_MAPS_API_KEY` | `""` | Route intelligence (falls back to formula) |
| `AUTOMATION_INTERVAL_SECONDS` | `300` | How often automation runs |
| `OVERDUE_TRIP_HOURS` | `8` | Hours before trip is flagged overdue |

---

## Frontend Build

Built via Docker using `ghcr.io/cirruslabs/flutter:stable`.

```dockerfile
flutter build web --release --dart-define=API_BASE_URL=https://...
nginx serves build/web/
```

**Mobile web fix (Phase 10):** Storage uses conditional imports — `dart:html` only on web, `flutter_secure_storage` on native. No more blank page on mobile browsers.

---

## Deployment Checklist

Before pushing to `staging-release`:
- [ ] Python syntax valid (`python3 -m py_compile`)
- [ ] No hardcoded secrets
- [ ] New API routes registered in `main.py`
- [ ] New Flutter screens imported in `app_drawer.dart`
- [ ] `SECRET_KEY` set in Railway environment

After deployment:
- [ ] `GET /health` returns 200
- [ ] `GET /automation/status` returns cycle summary
- [ ] Login works on mobile and desktop
- [ ] New screens visible in drawer for MANAGER role

---

## Rollback

In Railway dashboard → frontend/backend service → Deployments → click previous successful deployment → Redeploy.
