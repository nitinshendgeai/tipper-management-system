#!/usr/bin/env python3
"""
run_db_init.py — One-off database initialisation script.

Runs the full schema repair (ALTER TABLE column backfills, CREATE INDEX,
per-company unique constraints) and legacy seed data (roles + admin user).

Usage
─────
# From the backend/ directory:
    python scripts/run_db_init.py

# As a Railway one-off job (Settings → Jobs → "Run Command"):
    cd backend && python scripts/run_db_init.py

Why this exists
───────────────
Phase 6 moved repair_existing_schema() and seed_data() out of the blocking
FastAPI startup event into a background thread so Railway healthchecks pass
immediately. This script lets you run those tasks manually:

  • After a fresh DB reset / wipe
  • When deploying to a new Railway environment for the first time
  • When you need to force-apply new indexes or constraints added in bootstrap.py
  • To debug seed issues without restarting the full app

The script is fully idempotent — safe to run multiple times.
All statements use IF NOT EXISTS guards.
"""

import logging
import sys
import time

# ── Make sure app package is importable ──────────────────────────────────────
import os

# Add the backend/ directory to sys.path so imports work when run as a script
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.bootstrap import ensure_database_schemas, repair_existing_schema
from app.db.seed import seed_data
from app.db.session import Base, engine

logging.basicConfig(
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
    stream=sys.stdout,
)
logger = logging.getLogger("db-init")


def main() -> int:
    t_start = time.perf_counter()
    logger.info("=== Tipper ERP — manual DB init starting ===")

    # ── Step 1: Ensure PostgreSQL schemas ────────────────────────────────────
    t1 = time.perf_counter()
    logger.info("[1/4] ensure_database_schemas() — CREATE SCHEMA IF NOT EXISTS ×4")
    try:
        ensure_database_schemas(engine)
        logger.info("[1/4] done (%.2fs)", time.perf_counter() - t1)
    except Exception as exc:
        logger.error("[1/4] FAILED: %s", exc, exc_info=True)
        return 1

    # ── Step 2: Create / verify all tables ──────────────────────────────────
    t2 = time.perf_counter()
    logger.info("[2/4] Base.metadata.create_all() — CREATE TABLE IF NOT EXISTS")
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("[2/4] done (%.2fs)", time.perf_counter() - t2)
    except Exception as exc:
        logger.error("[2/4] FAILED: %s", exc, exc_info=True)
        return 1

    # ── Step 3: Column backfills, indexes, unique constraints ────────────────
    t3 = time.perf_counter()
    logger.info("[3/4] repair_existing_schema() — ALTER TABLE + CREATE INDEX + DO blocks")
    try:
        repair_existing_schema(engine)
        logger.info("[3/4] done (%.2fs)", time.perf_counter() - t3)
    except Exception as exc:
        logger.error("[3/4] FAILED: %s", exc, exc_info=True)
        return 1

    # ── Step 4: Seed legacy roles + admin user ───────────────────────────────
    t4 = time.perf_counter()
    logger.info("[4/4] seed_data() — legacy roles + admin@tipper.com")
    try:
        seed_data()
        logger.info("[4/4] done (%.2fs)", time.perf_counter() - t4)
    except Exception as exc:
        logger.error("[4/4] FAILED: %s", exc, exc_info=True)
        return 1

    total = time.perf_counter() - t_start
    logger.info("=== DB init complete in %.2fs ===", total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
