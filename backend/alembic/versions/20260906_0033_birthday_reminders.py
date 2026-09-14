"""Add durable automatic birthday reminder state and system campaigns."""

from alembic import op
import sqlalchemy as sa


revision = '20260906_0033'
down_revision = '20260906_0032'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint('ck_push_campaigns_audience_type', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_audience_type',
        'push_campaigns',
        "audience_type IN ('all_users', 'birthday_in_days', 'user')",
    )
    op.add_column(
        'push_campaigns',
        sa.Column('origin', sa.String(length=32), nullable=False, server_default='manual'),
    )
    op.create_check_constraint(
        'ck_push_campaigns_origin',
        'push_campaigns',
        "origin IN ('manual', 'system_birthday')",
    )
    op.alter_column(
        'push_campaigns',
        'created_by_admin_id',
        existing_type=sa.String(length=32),
        nullable=True,
    )

    op.create_table(
        'birthday_reminders',
        sa.Column('id', sa.String(length=32), primary_key=True),
        sa.Column('child_id', sa.String(length=32), nullable=True),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('birthday_year', sa.Integer(), nullable=False),
        sa.Column('days_before', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(length=16), nullable=False, server_default='pending'),
        sa.Column('push_campaign_id', sa.String(length=32), nullable=True),
        sa.Column('skip_reason', sa.String(length=64), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('sent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('skipped_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['child_id'], ['mobile_children.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['push_campaign_id'], ['push_campaigns.id'], ondelete='SET NULL'),
        sa.UniqueConstraint('child_id', 'birthday_year', 'days_before', name='uq_birthday_reminders_child_year_window'),
        sa.CheckConstraint("status IN ('pending', 'sent', 'skipped', 'failed')", name='ck_birthday_reminders_status'),
        sa.CheckConstraint('days_before IN (14, 7, 1)', name='ck_birthday_reminders_days_before'),
    )
    op.create_index('ix_birthday_reminders_child_id', 'birthday_reminders', ['child_id'])
    op.create_index('ix_birthday_reminders_mobile_user_id', 'birthday_reminders', ['mobile_user_id'])
    op.create_index('ix_birthday_reminders_status', 'birthday_reminders', ['status'])
    op.create_index('ix_birthday_reminders_push_campaign_id', 'birthday_reminders', ['push_campaign_id'])


def downgrade() -> None:
    op.drop_index('ix_birthday_reminders_push_campaign_id', table_name='birthday_reminders')
    op.drop_index('ix_birthday_reminders_status', table_name='birthday_reminders')
    op.drop_index('ix_birthday_reminders_mobile_user_id', table_name='birthday_reminders')
    op.drop_index('ix_birthday_reminders_child_id', table_name='birthday_reminders')
    op.drop_table('birthday_reminders')
    op.alter_column(
        'push_campaigns',
        'created_by_admin_id',
        existing_type=sa.String(length=32),
        nullable=False,
    )
    op.drop_constraint('ck_push_campaigns_origin', 'push_campaigns', type_='check')
    op.drop_column('push_campaigns', 'origin')
    op.drop_constraint('ck_push_campaigns_audience_type', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_audience_type',
        'push_campaigns',
        "audience_type IN ('all_users', 'birthday_in_days')",
    )
