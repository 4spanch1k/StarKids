"""Track only new paid payments that still need loyalty settlement."""

from alembic import op
import sqlalchemy as sa


revision = '20260906_0028'
down_revision = '20260905_0027'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'mobile_payments',
        sa.Column(
            'loyalty_settlement_required',
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.create_index(
        'ix_mobile_payments_loyalty_settlement_required',
        'mobile_payments',
        ['loyalty_settlement_required'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        'ix_mobile_payments_loyalty_settlement_required',
        table_name='mobile_payments',
    )
    op.drop_column('mobile_payments', 'loyalty_settlement_required')
