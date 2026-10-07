"""Add explicit partial delivery status and campaign failure reason."""

from alembic import op
import sqlalchemy as sa


revision = '20260919_0040'
down_revision = '20260914_0039'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('push_campaigns', sa.Column('failure_reason', sa.String(length=128), nullable=True))
    op.drop_constraint('ck_push_campaigns_status', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_status',
        'push_campaigns',
        "status IN ('draft', 'scheduled', 'processing', 'sent', 'partially_failed', 'failed', 'cancelled')",
    )


def downgrade() -> None:
    op.execute("UPDATE push_campaigns SET status = 'failed' WHERE status = 'partially_failed'")
    op.drop_constraint('ck_push_campaigns_status', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_status',
        'push_campaigns',
        "status IN ('draft', 'scheduled', 'processing', 'sent', 'failed', 'cancelled')",
    )
    op.drop_column('push_campaigns', 'failure_reason')
