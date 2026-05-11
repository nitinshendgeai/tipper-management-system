from jose import jwt, JWTError

from fastapi import Depends, HTTPException

from fastapi.security import HTTPBearer
from fastapi.security.http import HTTPAuthorizationCredentials

from sqlalchemy.orm import Session

from app.core.config import (
    SECRET_KEY,
    ALGORITHM
)

from app.db.session import SessionLocal
from app.models.user import User

security = HTTPBearer()


def get_db():

    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):

    token = credentials.credentials

    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials"
    )

    try:

        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        email: str = payload.get("sub")

        if email is None:
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    user = db.query(User).filter(
        User.email == email
    ).first()

    if user is None:
        raise credentials_exception

    return user