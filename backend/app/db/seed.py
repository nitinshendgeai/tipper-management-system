from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models.role import Role
from app.models.user import User

from app.core.security import hash_password


def seed_data():

    db: Session = SessionLocal()

    # CREATE ROLES

    roles = [
        "Admin",
        "Manager",
        "Dispatcher",
        "Driver",
        "Accounts"
    ]

    for role_name in roles:

        existing_role = db.query(Role).filter(
            Role.name == role_name
        ).first()

        if not existing_role:

            role = Role(
                name=role_name
            )

            db.add(role)

    db.commit()

    # GET ADMIN ROLE

    admin_role = db.query(Role).filter(
        Role.name == "Admin"
    ).first()

    # CREATE ADMIN USER

    admin_user = db.query(User).filter(
        User.email == "admin@tipper.com"
    ).first()

    if not admin_user:

        admin_user = User(
            role_id=admin_role.id,
            full_name="System Admin",
            email="admin@tipper.com",
            password_hash=hash_password("admin123")
        )

        db.add(admin_user)

        db.commit()

    db.close()