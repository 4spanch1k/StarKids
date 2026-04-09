"""Mobile auth profile support with users and persistent sessions."""

from alembic import op
import sqlalchemy as sa


revision = '20260408_0004'
down_revision = '20260407_0003'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'mobile_users',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('phone', sa.String(length=32), nullable=False),
        sa.Column(
            'is_active',
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
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_mobile_users_phone'),
        'mobile_users',
        ['phone'],
        unique=True,
    )

    op.create_table(
        'mobile_sessions',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('refresh_token_hash', sa.String(length=64), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column('last_used_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_mobile_sessions_mobile_user_id'),
        'mobile_sessions',
        ['mobile_user_id'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f('ix_mobile_sessions_mobile_user_id'), table_name='mobile_sessions')
    op.drop_table('mobile_sessions')

    op.drop_index(op.f('ix_mobile_users_phone'), table_name='mobile_users')
    op.drop_table('mobile_users')
