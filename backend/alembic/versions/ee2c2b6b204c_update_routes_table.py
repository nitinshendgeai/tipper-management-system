"""update_routes_table

Revision ID: ee2c2b6b204c
Revises: 64e866bd0f40
Create Date: 2026-05-10 17:03:28.879429
"""
from typing import Sequence, Union


revision: str = "ee2c2b6b204c"
down_revision: Union[str, Sequence[str], None] = "64e866bd0f40"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Current schema is created by the initial migration.
    pass


def downgrade() -> None:
    pass
