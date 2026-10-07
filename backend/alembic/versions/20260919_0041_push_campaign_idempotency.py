"""Add persisted idempotency keys for manual push campaign creation."""

from alembic import op
import sqlalchemy as sa


revision = '20260919_0041'
down_revision = '20260919_0040'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('push_campaigns', sa.Column('idempotency_key', sa.String(length=128), nullable=True))
    op.create_unique_constraint(
        'uq_push_campaigns_admin_idempotency',
        'push_campaigns',
        ['created_by_admin_id', 'idempotency_key'],
    )


def downgrade() -> None:
    op.drop_constraint('uq_push_campaigns_admin_idempotency', 'push_campaigns', type_='unique')
    op.drop_column('push_campaigns', 'idempotency_key')
