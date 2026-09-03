"""Add typed notification destinations."""

from alembic import op
import sqlalchemy as sa


revision = '20260903_0024'
down_revision = '20260903_0023'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('mobile_notifications', sa.Column('destination_type', sa.String(length=32), nullable=True))
    op.add_column('mobile_notifications', sa.Column('destination_id', sa.String(length=64), nullable=True))
    op.create_index('ix_mobile_notifications_destination', 'mobile_notifications', ['destination_type', 'destination_id'])


def downgrade() -> None:
    op.drop_index('ix_mobile_notifications_destination', table_name='mobile_notifications')
    op.drop_column('mobile_notifications', 'destination_id')
    op.drop_column('mobile_notifications', 'destination_type')
