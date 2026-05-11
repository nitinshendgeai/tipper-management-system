from fastapi import (
    HTTPException,
    Depends
)

from app.api.dependencies import get_current_user


class RoleChecker:

    def __init__(self, allowed_roles):

        self.allowed_roles = allowed_roles

    def __call__(
        self,
        current_user=Depends(get_current_user)
    ):

        if current_user.role_id not in self.allowed_roles:

            raise HTTPException(
                status_code=403,
                detail="Permission denied"
            )

        return current_user