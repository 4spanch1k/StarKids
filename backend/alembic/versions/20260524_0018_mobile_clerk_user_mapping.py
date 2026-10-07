"""Add Clerk user mapping for mobile users."""

from alembic import op
import sqlalchemy as sa


revision = '20260524_0018'
down_revision = '20260421_0017'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'mobile_users',
        sa.Column('clerk_user_id', sa.String(length=255), nullable=True),
    )
    op.create_index(
        op.f('ix_mobile_users_clerk_user_id'),
        'mobile_users',
        ['clerk_user_id'],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(op.f('ix_mobile_users_clerk_user_id'), table_name='mobile_users')
    op.drop_column('mobile_users', 'clerk_user_id')
