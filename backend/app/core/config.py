from dotenv import load_dotenv
import os

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

SECRET_KEY = "tipper-secret-key"

ALGORITHM = "HS256"

ACCESS_TOKEN_EXPIRE_MINUTES = 60

# ─── Google Maps ──────────────────────────────────────────────────────────────
# Set GOOGLE_MAPS_API_KEY in your .env file.
# If not set, route intelligence falls back to a formula-based estimate.
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")

# ─── Fleet constants ─────────────────────────────────────────────────────────
# Tipper truck average fuel efficiency (km per litre) — used for diesel estimate
TIPPER_FUEL_EFFICIENCY_KM_PER_LITRE = float(
    os.getenv("TIPPER_FUEL_EFFICIENCY_KM_PER_LITRE", "5.0")
)
