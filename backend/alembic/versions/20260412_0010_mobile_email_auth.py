"""Add email auth fields for mobile users."""

from alembic import op
import sqlalchemy as sa


revision = '20260412_0010'
down_revision = '20260412_0009'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'mobile_users',
        sa.Column('email', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'mobile_users',
        sa.Column('password_hash', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'mobile_users',
        sa.Column(
            'updated_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.alter_column(
        'mobile_users',
        'phone',
        existing_type=sa.String(length=32),
        nullable=True,
    )
    op.create_index(
        op.f('ix_mobile_users_email'),
        'mobile_users',
        ['email'],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(op.f('ix_mobile_users_email'), table_name='mobile_users')
    op.alter_column(
        'mobile_users',
        'phone',
        existing_type=sa.String(length=32),
        nullable=False,
    )
    op.drop_column('mobile_users', 'updated_at')
    op.drop_column('mobile_users', 'password_hash')
    op.drop_column('mobile_users', 'email')
