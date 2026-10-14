"""Add ticket payment bonus/cash snapshots and reservation expiry."""

from alembic import op
import sqlalchemy as sa


revision = '20260905_0027'
down_revision = '20260905_0026'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('mobile_payments', sa.Column('gross_amount_tenge', sa.Integer(), nullable=True))
    op.add_column('mobile_payments', sa.Column('bonus_amount', sa.Integer(), nullable=True))
    op.add_column('mobile_payments', sa.Column('cash_amount_tenge', sa.Integer(), nullable=True))
    op.add_column('mobile_payments', sa.Column('loyalty_reservation_id', sa.String(length=32), nullable=True))
    op.add_column('mobile_payments', sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True))
    op.execute('UPDATE mobile_payments SET gross_amount_tenge = amount_tenge, bonus_amount = 0, cash_amount_tenge = amount_tenge WHERE gross_amount_tenge IS NULL')
    op.alter_column('mobile_payments', 'gross_amount_tenge', nullable=False, server_default='0')
    op.alter_column('mobile_payments', 'bonus_amount', nullable=False, server_default='0')
    op.alter_column('mobile_payments', 'cash_amount_tenge', nullable=False, server_default='0')
    op.create_index('ix_mobile_payments_loyalty_reservation_id', 'mobile_payments', ['loyalty_reservation_id'], unique=False)
    op.create_index('ix_mobile_payments_expires_at', 'mobile_payments', ['expires_at'], unique=False)
    op.create_check_constraint('ck_mobile_payments_bonus_nonnegative', 'mobile_payments', 'bonus_amount >= 0')
    op.create_check_constraint('ck_mobile_payments_cash_nonnegative', 'mobile_payments', 'cash_amount_tenge >= 0')
    op.create_check_constraint('ck_mobile_payments_gross_breakdown', 'mobile_payments', 'gross_amount_tenge = bonus_amount + cash_amount_tenge')


def downgrade() -> None:
    op.drop_constraint('ck_mobile_payments_gross_breakdown', 'mobile_payments', type_='check')
    op.drop_constraint('ck_mobile_payments_cash_nonnegative', 'mobile_payments', type_='check')
    op.drop_constraint('ck_mobile_payments_bonus_nonnegative', 'mobile_payments', type_='check')
    op.drop_index('ix_mobile_payments_expires_at', table_name='mobile_payments')
    op.drop_index('ix_mobile_payments_loyalty_reservation_id', table_name='mobile_payments')
    op.drop_column('mobile_payments', 'expires_at')
    op.drop_column('mobile_payments', 'loyalty_reservation_id')
    op.drop_column('mobile_payments', 'cash_amount_tenge')
    op.drop_column('mobile_payments', 'bonus_amount')
    op.drop_column('mobile_payments', 'gross_amount_tenge')
