"""Add payment idempotency and callback audit storage."""

from alembic import op
import sqlalchemy as sa


revision = '20260831_0019'
down_revision = '20260524_0018'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'mobile_payments',
        sa.Column('idempotency_key', sa.String(length=128), nullable=True),
    )
    op.add_column(
        'mobile_payments',
        sa.Column('payment_url', sa.String(length=512), nullable=True),
    )
    # Existing rows predate idempotency. Keep them readable while requiring the
    # key for every new checkout created by the updated application.
    op.create_index(
        'uq_mobile_payments_user_idempotency',
        'mobile_payments',
        ['mobile_user_id', 'idempotency_key'],
        unique=True,
    )
    op.create_table(
        'mobile_payment_callbacks',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('mobile_payment_id', sa.String(length=32), nullable=False),
        sa.Column('local_order_id', sa.String(length=64), nullable=False),
        sa.Column('provider_event_id', sa.String(length=128), nullable=True),
        sa.Column('payload_fingerprint', sa.String(length=64), nullable=False),
        sa.Column('payload', sa.JSON(), nullable=False),
        sa.Column('result', sa.String(length=32), nullable=False),
        sa.Column('status_before', sa.String(length=32), nullable=False),
        sa.Column('status_after', sa.String(length=32), nullable=False),
        sa.Column('failure_reason', sa.Text(), nullable=True),
        sa.Column('duplicate_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column(
            'received_at',
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ['mobile_payment_id'],
            ['mobile_payments.id'],
            ondelete='CASCADE',
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('payload_fingerprint', name='uq_mobile_payment_callback_fingerprint'),
    )
    op.create_index(
        'ix_mobile_payment_callbacks_mobile_payment_id',
        'mobile_payment_callbacks',
        ['mobile_payment_id'],
    )
    op.create_index(
        'ix_mobile_payment_callbacks_local_order_id',
        'mobile_payment_callbacks',
        ['local_order_id'],
    )
    op.create_index(
        'ix_mobile_payment_callbacks_provider_event_id',
        'mobile_payment_callbacks',
        ['provider_event_id'],
    )


def downgrade() -> None:
    op.drop_index(
        'ix_mobile_payment_callbacks_provider_event_id',
        table_name='mobile_payment_callbacks',
    )
    op.drop_index(
        'ix_mobile_payment_callbacks_local_order_id',
        table_name='mobile_payment_callbacks',
    )
    op.drop_index(
        'ix_mobile_payment_callbacks_mobile_payment_id',
        table_name='mobile_payment_callbacks',
    )
    op.drop_table('mobile_payment_callbacks')
    op.drop_index('uq_mobile_payments_user_idempotency', table_name='mobile_payments')
    op.drop_column('mobile_payments', 'payment_url')
    op.drop_column('mobile_payments', 'idempotency_key')
