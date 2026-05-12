from fastapi import (
    APIRouter,
    Depends,
    HTTPException
)

from sqlalchemy.orm import Session

from app.db.session import SessionLocal

from app.models.route import Route

from app.schemas.route_schema import (
    RouteCreate,
    RouteUpdate,
    RouteResponse
)

from app.api.dependencies import require_permission
from app.core.permissions import Permission
from app.db.tenant_queries import filter_by_company


router = APIRouter()


def get_db():

    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()


# ─── CREATE ───────────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=RouteResponse,
    summary="Create a new route (MANAGER or above)"
)
def create_route(
    data: RouteCreate,
    current_user=Depends(require_permission(Permission.MANAGE_ROUTES)),
    db: Session = Depends(get_db)
):

    route = Route(
        company_id=current_user.company_id,
        source_location=data.source_location,
        destination_location=data.destination_location,
        distance_km=data.distance_km,
        trip_rate=data.trip_rate,
        diesel_limit=data.diesel_limit,
        estimated_hours=data.estimated_hours,
        remarks=data.remarks
    )

    db.add(route)
    db.commit()
    db.refresh(route)

    return route


# ─── READ ALL ─────────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=list[RouteResponse],
    summary="List all active routes"
)
def list_routes(
    current_user=Depends(require_permission(Permission.VIEW_ROUTES)),
    db: Session = Depends(get_db)
):

    routes = filter_by_company(
        db.query(Route), Route
    ).filter(Route.is_active == True).all()

    return routes


# ─── READ ONE ─────────────────────────────────────────────────────────────────

@router.get(
    "/{route_id}",
    response_model=RouteResponse,
    summary="Get a single route by ID"
)
def get_route(
    route_id: int,
    current_user=Depends(require_permission(Permission.VIEW_ROUTES)),
    db: Session = Depends(get_db)
):

    route = filter_by_company(
        db.query(Route), Route
    ).filter(
        Route.id == route_id,
        Route.is_active == True
    ).first()

    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    return route


# ─── UPDATE ───────────────────────────────────────────────────────────────────

@router.put(
    "/{route_id}",
    response_model=RouteResponse,
    summary="Update a route (MANAGER or above)"
)
def update_route(
    route_id: int,
    data: RouteUpdate,
    current_user=Depends(require_permission(Permission.MANAGE_ROUTES)),
    db: Session = Depends(get_db)
):

    route = filter_by_company(
        db.query(Route), Route
    ).filter(
        Route.id == route_id,
        Route.is_active == True
    ).first()

    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    update_data = data.dict(exclude_unset=True)

    for key, value in update_data.items():
        setattr(route, key, value)

    db.commit()
    db.refresh(route)

    return route


# ─── DELETE (soft) ────────────────────────────────────────────────────────────

@router.delete(
    "/{route_id}",
    summary="Soft-delete a route (MANAGER or above)"
)
def delete_route(
    route_id: int,
    current_user=Depends(require_permission(Permission.MANAGE_ROUTES)),
    db: Session = Depends(get_db)
):

    route = filter_by_company(
        db.query(Route), Route
    ).filter(
        Route.id == route_id,
        Route.is_active == True
    ).first()

    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    # Soft delete — preserves trip history referencing this route
    route.is_active = False
    db.commit()

    return {
        "message": f"Route {route.source_location} → {route.destination_location} deleted successfully"
    }
