"""Harden auth password, throttle, captcha and session storage."""

from alembic import op
import sqlalchemy as sa


revision = '20260420_0014'
down_revision = '20260416_0013'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'admin_users',
        sa.Column('last_login_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'mobile_users',
        sa.Column('last_login_at', sa.DateTime(timezone=True), nullable=True),
    )

    op.alter_column(
        'admin_sessions',
        'refresh_token_hash',
        existing_type=sa.String(length=64),
        type_=sa.String(length=255),
        existing_nullable=False,
    )
    op.alter_column(
        'mobile_sessions',
        'refresh_token_hash',
        existing_type=sa.String(length=64),
        type_=sa.String(length=255),
        existing_nullable=False,
    )

    op.create_table(
        'auth_throttle_states',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('auth_scope', sa.String(length=64), nullable=False),
        sa.Column('bucket_type', sa.String(length=32), nullable=False),
        sa.Column('bucket_key', sa.String(length=255), nullable=False),
        sa.Column('ip_address', sa.String(length=64), nullable=False),
        sa.Column('identifier', sa.String(length=255), nullable=True),
        sa.Column(
            'failed_attempts',
            sa.Integer(),
            nullable=False,
            server_default=sa.text('0'),
        ),
        sa.Column(
            'total_lockouts',
            sa.Integer(),
            nullable=False,
            server_default=sa.text('0'),
        ),
        sa.Column(
            'post_lock_failures',
            sa.Integer(),
            nullable=False,
            server_default=sa.text('0'),
        ),
        sa.Column('lockout_until', sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            'captcha_required',
            sa.Boolean(),
            nullable=False,
            server_default=sa.text('0'),
        ),
        sa.Column('captcha_id', sa.String(length=32), nullable=True),
        sa.Column('captcha_prompt', sa.String(length=255), nullable=True),
        sa.Column('captcha_answer_hash', sa.String(length=64), nullable=True),
        sa.Column('captcha_expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_failed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_success_at', sa.DateTime(timezone=True), nullable=True),
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
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'auth_scope',
            'bucket_type',
            'bucket_key',
            name='uq_auth_throttle_states_scope_bucket',
        ),
    )
    op.create_index(
        op.f('ix_auth_throttle_states_auth_scope'),
        'auth_throttle_states',
        ['auth_scope'],
        unique=False,
    )
    op.create_index(
        op.f('ix_auth_throttle_states_bucket_type'),
        'auth_throttle_states',
        ['bucket_type'],
        unique=False,
    )
    op.create_index(
        op.f('ix_auth_throttle_states_ip_address'),
        'auth_throttle_states',
        ['ip_address'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f('ix_auth_throttle_states_ip_address'),
        table_name='auth_throttle_states',
    )
    op.drop_index(
        op.f('ix_auth_throttle_states_bucket_type'),
        table_name='auth_throttle_states',
    )
    op.drop_index(
        op.f('ix_auth_throttle_states_auth_scope'),
        table_name='auth_throttle_states',
    )
    op.drop_table('auth_throttle_states')

    op.alter_column(
        'mobile_sessions',
        'refresh_token_hash',
        existing_type=sa.String(length=255),
        type_=sa.String(length=64),
        existing_nullable=False,
    )
    op.alter_column(
        'admin_sessions',
        'refresh_token_hash',
        existing_type=sa.String(length=255),
        type_=sa.String(length=64),
        existing_nullable=False,
    )

    op.drop_column('mobile_users', 'last_login_at')
    op.drop_column('admin_users', 'last_login_at')
