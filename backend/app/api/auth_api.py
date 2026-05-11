from fastapi import (
    APIRouter,
    HTTPException,
    Depends
)

from app.db.session import SessionLocal
from app.models.user import User

from app.schemas.auth_schema import (
    LoginRequest,
    TokenResponse
)

from app.core.security import (
    verify_password,
    create_access_token
)

from app.api.dependencies import get_current_user

router = APIRouter()


@router.post(
    "/login",
    response_model=TokenResponse
)
def login(data: LoginRequest):

    db = SessionLocal()

    user = db.query(User).filter(
        User.email == data.email
    ).first()

    if not user:

        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    if not verify_password(
        data.password,
        user.password_hash
    ):

        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    access_token = create_access_token(
        data={
            "sub": user.email,
            "role_id": user.role_id
        }
    )

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.get("/me")
def current_user(
    current_user: User = Depends(get_current_user)
):

    return {
        "id": current_user.id,
        "full_name": current_user.full_name,
        "email": current_user.email,
        "role_id": current_user.role_id
    }