"""Add manual push campaign snapshots and delivery audit."""

from alembic import op
import sqlalchemy as sa


revision = '20260906_0031'
down_revision = '20260906_0030'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'push_campaigns',
        sa.Column('id', sa.String(length=32), primary_key=True),
        sa.Column('internal_name', sa.String(length=150), nullable=False),
        sa.Column('title', sa.String(length=100), nullable=False),
        sa.Column('body', sa.Text(), nullable=False),
        sa.Column('audience_type', sa.String(length=32), nullable=False),
        sa.Column('audience_config', sa.JSON(), nullable=False),
        sa.Column('destination', sa.String(length=32), nullable=False),
        sa.Column('destination_payload', sa.JSON(), nullable=False),
        sa.Column('status', sa.String(length=16), nullable=False, server_default='draft'),
        sa.Column('scheduled_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('sent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('cancelled_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by_admin_id', sa.String(length=32), sa.ForeignKey('admin_users.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('targeted_users', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('targeted_devices', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('sent_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('failed_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("audience_type IN ('all_users', 'birthday_in_days')", name='ck_push_campaigns_audience_type'),
        sa.CheckConstraint("destination IN ('home', 'tickets', 'birthdays', 'promotions', 'profile')", name='ck_push_campaigns_destination'),
        sa.CheckConstraint("status IN ('draft', 'scheduled', 'processing', 'sent', 'failed', 'cancelled')", name='ck_push_campaigns_status'),
    )
    op.create_index('ix_push_campaigns_status', 'push_campaigns', ['status'])
    op.create_index('ix_push_campaigns_scheduled_at', 'push_campaigns', ['scheduled_at'])
    op.create_index('ix_push_campaigns_created_by_admin_id', 'push_campaigns', ['created_by_admin_id'])
    op.create_table(
        'push_campaign_deliveries',
        sa.Column('id', sa.String(length=32), primary_key=True),
        sa.Column('campaign_id', sa.String(length=32), sa.ForeignKey('push_campaigns.id', ondelete='CASCADE'), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), sa.ForeignKey('mobile_users.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('device_id', sa.String(length=32), sa.ForeignKey('mobile_notification_devices.id', ondelete='SET NULL'), nullable=True),
        sa.Column('token_snapshot', sa.String(length=512), nullable=False),
        sa.Column('status', sa.String(length=16), nullable=False, server_default='pending'),
        sa.Column('attempt_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('provider_message_id', sa.String(length=255), nullable=True),
        sa.Column('last_error_code', sa.String(length=64), nullable=True),
        sa.Column('last_error_message', sa.String(length=255), nullable=True),
        sa.Column('sent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint('campaign_id', 'device_id', name='uq_push_campaign_deliveries_campaign_device'),
        sa.CheckConstraint("status IN ('pending', 'sending', 'sent', 'failed')", name='ck_push_campaign_deliveries_status'),
    )
    op.create_index('ix_push_campaign_deliveries_campaign_id', 'push_campaign_deliveries', ['campaign_id'])
    op.create_index('ix_push_campaign_deliveries_mobile_user_id', 'push_campaign_deliveries', ['mobile_user_id'])
    op.create_index('ix_push_campaign_deliveries_device_id', 'push_campaign_deliveries', ['device_id'])
    op.create_index('ix_push_campaign_deliveries_status', 'push_campaign_deliveries', ['status'])


def downgrade() -> None:
    op.drop_table('push_campaign_deliveries')
    op.drop_table('push_campaigns')
