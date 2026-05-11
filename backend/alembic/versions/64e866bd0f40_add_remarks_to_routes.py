"""add_remarks_to_routes

Revision ID: 64e866bd0f40
Revises: 6c49d61bb804
Create Date: 2026-05-10 16:54:38.384500
"""
from typing import Sequence, Union


revision: str = "64e866bd0f40"
down_revision: Union[str, Sequence[str], None] = "6c49d61bb804"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Current schema is created by the initial migration.
    pass


def downgrade() -> None:
    pass
