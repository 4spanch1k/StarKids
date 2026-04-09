"""Add mobile notification device registration support."""

from alembic import op
import sqlalchemy as sa


revision = '20260409_0007'
down_revision = '20260409_0006'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'mobile_notification_devices',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('mobile_session_id', sa.String(length=32), nullable=False),
        sa.Column('platform', sa.String(length=16), nullable=False),
        sa.Column('push_token', sa.String(length=512), nullable=False),
        sa.Column(
            'permission_status',
            sa.String(length=32),
            nullable=False,
            server_default='unknown',
        ),
        sa.Column(
            'notifications_enabled',
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            'updated_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ['mobile_session_id'],
            ['mobile_sessions.id'],
            ondelete='CASCADE',
        ),
        sa.ForeignKeyConstraint(
            ['mobile_user_id'],
            ['mobile_users.id'],
            ondelete='CASCADE',
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'mobile_session_id',
            name='uq_mobile_notification_devices_mobile_session_id',
        ),
        sa.UniqueConstraint(
            'push_token',
            name='uq_mobile_notification_devices_push_token',
        ),
    )
    op.create_index(
        op.f('ix_mobile_notification_devices_mobile_user_id'),
        'mobile_notification_devices',
        ['mobile_user_id'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f('ix_mobile_notification_devices_mobile_user_id'),
        table_name='mobile_notification_devices',
    )
    op.drop_table('mobile_notification_devices')
