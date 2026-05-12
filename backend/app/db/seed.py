from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models.role import Role
from app.models.user import User

from app.core.security import hash_password


def seed_data():

    print("[seed] seed_data() called — starting database seed")

    db: Session = SessionLocal()

    try:

        # CREATE ROLES

        roles = [
            "Admin",
            "Manager",
            "Dispatcher",
            "Driver",
            "Accounts"
        ]

        print(f"[seed] Seeding {len(roles)} roles: {roles}")

        roles_created = 0

        for role_name in roles:

            existing_role = db.query(Role).filter(
                Role.name == role_name
            ).first()

            if not existing_role:

                role = Role(
                    name=role_name
                )

                db.add(role)
                roles_created += 1

        db.commit()
        print(f"[seed] Roles committed — {roles_created} new role(s) created, {len(roles) - roles_created} already existed")

        # GET ADMIN ROLE

        admin_role = db.query(Role).filter(
            Role.name == "Admin"
        ).first()

        if not admin_role:
            print("[seed] ERROR: Admin role not found after seeding roles — cannot create admin user")
            return

        print(f"[seed] Admin role found (id={admin_role.id})")

        # CREATE ADMIN USER

        admin_user = db.query(User).filter(
            User.email == "admin@tipper.com"
        ).first()

        if not admin_user:

            print("[seed] Admin user not found — creating admin@tipper.com")

            admin_user = User(
                role_id=admin_role.id,
                full_name="System Admin",
                email="admin@tipper.com",
                password_hash=hash_password("admin123")
            )

            db.add(admin_user)

            db.commit()
            print("[seed] Admin user created and committed successfully")

        else:

            print(f"[seed] Admin user already exists (id={admin_user.id}) — skipping creation")

    except Exception as e:

        print(f"[seed] EXCEPTION during seed_data(): {type(e).__name__}: {e}")
        db.rollback()
        raise

    finally:

        db.close()
        print("[seed] seed_data() complete — database session closed")