"""Add promotion validity window timestamps."""

from alembic import op
import sqlalchemy as sa


revision = '20260914_0039'
down_revision = '20260909_0038'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'promotions',
        sa.Column('start_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'promotions',
        sa.Column('end_at', sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('promotions', 'end_at')
    op.drop_column('promotions', 'start_at')
