from fastapi import (
    APIRouter,
    Depends
)

from app.api.role_checker import RoleChecker

admin_only = RoleChecker([1])

router = APIRouter()


@router.get("/dashboard")
def admin_dashboard(
    current_user=Depends(admin_only)
):

    return {
        "message": "Welcome Admin Dashboard",
        "user": current_user.full_name
    }