"""Add lifecycle and redemption source audit fields."""

from alembic import op
import sqlalchemy as sa


revision = '20260903_0023'
down_revision = '20260903_0022'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('visits', sa.Column('completion_reason', sa.String(length=32), nullable=True))
    op.add_column(
        'ticket_redemptions',
        sa.Column('source', sa.String(length=16), server_default='scan', nullable=False),
    )
    op.add_column('ticket_redemptions', sa.Column('reason', sa.String(length=64), nullable=True))


def downgrade() -> None:
    op.drop_column('ticket_redemptions', 'reason')
    op.drop_column('ticket_redemptions', 'source')
    op.drop_column('visits', 'completion_reason')
