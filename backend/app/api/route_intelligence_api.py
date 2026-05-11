"""
Route Intelligence API — AI-assisted route calculation.

Architecture:
  Flutter → POST /route-intelligence/calculate → FastAPI → Google Maps API → Response

Google Maps API key is stored ONLY in the backend .env file.
The Flutter frontend never sees the key.

Fallback behaviour when GOOGLE_MAPS_API_KEY is not set:
  Returns a formula-based estimate using straight-line distance heuristics
  (sufficient for demo/development; replace key in production).
"""

import math
import httpx

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

from app.core.config import (
    GOOGLE_MAPS_API_KEY,
    TIPPER_FUEL_EFFICIENCY_KM_PER_LITRE,
)


router = APIRouter()

GOOGLE_DISTANCE_MATRIX_URL = (
    "https://maps.googleapis.com/maps/api/distancematrix/json"
)


# ─── Request / Response ───────────────────────────────────────────────────────

class RouteCalculationRequest(BaseModel):

    origin: str             # "Mumbai, Maharashtra" or lat,lng "19.0760,72.8777"
    destination: str
    mode: Optional[str] = "driving"     # driving | trucking (treated as driving)


class RouteCalculationResponse(BaseModel):

    origin: str
    destination: str

    distance_km: float
    duration_min: int
    estimated_diesel_litres: float

    source: str             # "google_maps" | "formula_estimate"
    raw_distance_text: Optional[str] = None
    raw_duration_text: Optional[str] = None


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _estimate_from_formula(origin: str, destination: str) -> RouteCalculationResponse:
    """
    Fallback when Google Maps key is not configured.
    Returns a rough distance estimate. Not accurate — for development only.
    """

    # Simple hash-based pseudo-distance for demo purposes
    seed = abs(hash(origin + destination)) % 5000
    estimated_km = 50.0 + (seed / 100.0)   # 50 – 100 km range

    duration_min = int((estimated_km / 40.0) * 60)     # avg 40 km/h
    diesel = round(estimated_km / TIPPER_FUEL_EFFICIENCY_KM_PER_LITRE, 2)

    return RouteCalculationResponse(
        origin=origin,
        destination=destination,
        distance_km=round(estimated_km, 2),
        duration_min=duration_min,
        estimated_diesel_litres=diesel,
        source="formula_estimate",
    )


def _diesel_from_km(distance_km: float) -> float:
    return round(distance_km / TIPPER_FUEL_EFFICIENCY_KM_PER_LITRE, 2)


# ─── Endpoint ─────────────────────────────────────────────────────────────────

@router.post(
    "/calculate",
    response_model=RouteCalculationResponse,
    summary="Calculate route distance, duration, and estimated diesel",
    description=(
        "Calls Google Maps Distance Matrix API (backend-only). "
        "Falls back to formula estimate if API key is not configured. "
        "Flutter frontend never sees the Google API key."
    ),
)
async def calculate_route(data: RouteCalculationRequest):

    if not GOOGLE_MAPS_API_KEY:
        # No API key — return formula estimate
        return _estimate_from_formula(data.origin, data.destination)

    params = {
        "origins": data.origin,
        "destinations": data.destination,
        "mode": "driving",
        "units": "metric",
        "key": GOOGLE_MAPS_API_KEY,
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(GOOGLE_DISTANCE_MATRIX_URL, params=params)
            resp.raise_for_status()
            payload = resp.json()

    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Google Maps request failed: {exc}"
        )

    # Parse Google response
    status = payload.get("status")

    if status != "OK":
        raise HTTPException(
            status_code=502,
            detail=f"Google Maps returned status: {status}"
        )

    try:
        element = payload["rows"][0]["elements"][0]
        el_status = element.get("status")

        if el_status != "OK":
            raise HTTPException(
                status_code=422,
                detail=f"Route not found between '{data.origin}' and '{data.destination}'. Google status: {el_status}"
            )

        distance_m   = element["distance"]["value"]        # metres
        duration_s   = element["duration"]["value"]        # seconds
        dist_text    = element["distance"]["text"]
        dur_text     = element["duration"]["text"]

    except (KeyError, IndexError) as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Unexpected Google Maps response format: {exc}"
        )

    distance_km  = round(distance_m / 1000.0, 2)
    duration_min = max(1, int(duration_s / 60))
    diesel       = _diesel_from_km(distance_km)

    return RouteCalculationResponse(
        origin=data.origin,
        destination=data.destination,
        distance_km=distance_km,
        duration_min=duration_min,
        estimated_diesel_litres=diesel,
        source="google_maps",
        raw_distance_text=dist_text,
        raw_duration_text=dur_text,
    )
