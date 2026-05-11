"""initial migration

Revision ID: 6c49d61bb804
Revises:
Create Date: 2026-05-09 20:02:10.172500
"""
from typing import Sequence, Union

from alembic import op

from app.db.bootstrap import ensure_database_schemas
from app.db.session import Base
from app.models import *  # noqa: F401,F403 - register SQLAlchemy models


revision: str = "6c49d61bb804"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    ensure_database_schemas(bind.engine)
    Base.metadata.create_all(bind=bind)


def downgrade() -> None:
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
