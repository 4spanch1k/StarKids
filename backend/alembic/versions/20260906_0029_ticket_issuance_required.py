"""Track paid payments whose issued tickets still need reconciliation."""

from alembic import op
import sqlalchemy as sa


revision = '20260906_0029'
down_revision = '20260906_0028'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'mobile_payments',
        sa.Column(
            'ticket_issuance_required',
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.create_index(
        'ix_mobile_payments_ticket_issuance_required',
        'mobile_payments',
        ['ticket_issuance_required'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        'ix_mobile_payments_ticket_issuance_required',
        table_name='mobile_payments',
    )
    op.drop_column('mobile_payments', 'ticket_issuance_required')
