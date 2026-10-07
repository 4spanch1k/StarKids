"""mobile_profile_fields

Revision ID: 20260413_0011
Revises: 20260412_0010
Create Date: 2026-04-13 00:11:00.000000

"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = '20260413_0011'
down_revision: Union[str, None] = '20260412_0010'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('mobile_users', sa.Column('first_name', sa.String(50), nullable=True))
    op.add_column('mobile_users', sa.Column('last_name', sa.String(50), nullable=True))
    op.add_column('mobile_users', sa.Column('avatar_url', sa.String(512), nullable=True))
    op.add_column('mobile_users', sa.Column('child_birth_date', sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column('mobile_users', 'child_birth_date')
    op.drop_column('mobile_users', 'avatar_url')
    op.drop_column('mobile_users', 'last_name')
    op.drop_column('mobile_users', 'first_name')
