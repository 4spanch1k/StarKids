"""mobile_children

Revision ID: 20260415_0012
Revises: 20260413_0011
Create Date: 2026-04-15 00:12:00.000000

"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = '20260415_0012'
down_revision: Union[str, None] = '20260413_0011'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'mobile_children',
        sa.Column('id', sa.String(32), primary_key=True),
        sa.Column(
            'user_id',
            sa.String(32),
            sa.ForeignKey('mobile_users.id', ondelete='CASCADE'),
            nullable=False,
            index=True,
        ),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('birth_date', sa.Date(), nullable=False),
        sa.Column('gender', sa.String(10), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index('ix_mobile_children_user_id', 'mobile_children', ['user_id'])


def downgrade() -> None:
    op.drop_index('ix_mobile_children_user_id', table_name='mobile_children')
    op.drop_table('mobile_children')
