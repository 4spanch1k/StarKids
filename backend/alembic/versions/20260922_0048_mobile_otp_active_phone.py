"""Serialize active OTP challenges per phone."""

from alembic import op
import sqlalchemy as sa


revision = '20260922_0048'
down_revision = '20260922_0047'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        'uq_mobile_otp_challenges_active_phone',
        'mobile_otp_challenges',
        ['phone'],
        unique=True,
        postgresql_where=sa.text('consumed_at IS NULL'),
        sqlite_where=sa.text('consumed_at IS NULL'),
    )


def downgrade() -> None:
    op.drop_index(
        'uq_mobile_otp_challenges_active_phone',
        table_name='mobile_otp_challenges',
    )
