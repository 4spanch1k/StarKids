"""Add durable numeric provider transaction reference for Kaspi payments."""

from alembic import op
import sqlalchemy as sa


revision = '20261003_0049'
down_revision = '20260922_0048'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'mobile_payments',
        sa.Column('provider_transaction_reference', sa.String(length=20), nullable=True),
    )
    op.create_index(
        'ix_mobile_payments_provider_transaction_reference',
        'mobile_payments',
        ['provider_transaction_reference'],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        'ix_mobile_payments_provider_transaction_reference',
        table_name='mobile_payments',
    )
    op.drop_column('mobile_payments', 'provider_transaction_reference')
