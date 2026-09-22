"""Persist local development phone OTP challenges."""

from alembic import op
import sqlalchemy as sa


revision = '20260922_0047'
down_revision = '20260922_0046'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'mobile_otp_challenges',
        sa.Column('id', sa.String(length=64), primary_key=True),
        sa.Column('phone', sa.String(length=32), nullable=False),
        sa.Column('code_hash', sa.String(length=255), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('attempt_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('max_attempts', sa.Integer(), nullable=False),
        sa.Column('consumed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint('attempt_count >= 0', name='ck_mobile_otp_attempt_count'),
        sa.CheckConstraint('max_attempts > 0', name='ck_mobile_otp_max_attempts'),
    )
    op.create_index('ix_mobile_otp_challenges_phone', 'mobile_otp_challenges', ['phone'])
    op.create_index(
        'ix_mobile_otp_challenges_phone_created',
        'mobile_otp_challenges',
        ['phone', 'created_at'],
    )


def downgrade() -> None:
    op.drop_index('ix_mobile_otp_challenges_phone_created', table_name='mobile_otp_challenges')
    op.drop_index('ix_mobile_otp_challenges_phone', table_name='mobile_otp_challenges')
    op.drop_table('mobile_otp_challenges')
