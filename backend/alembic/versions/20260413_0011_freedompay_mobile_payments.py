"""Add mobile Freedom Pay payments."""

from alembic import op
import sqlalchemy as sa


revision = '20260413_0011'
down_revision = '20260412_0010'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'mobile_payments',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('payable_entity_type', sa.String(length=64), nullable=False),
        sa.Column('payable_entity_id', sa.String(length=32), nullable=False),
        sa.Column('local_order_id', sa.String(length=64), nullable=False),
        sa.Column('external_payment_id', sa.String(length=128), nullable=True),
        sa.Column('gateway', sa.String(length=32), nullable=False),
        sa.Column('amount_tenge', sa.Integer(), nullable=False),
        sa.Column('currency', sa.String(length=3), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('visit_date', sa.Date(), nullable=True),
        sa.Column('ticket_items', sa.JSON(), nullable=False),
        sa.Column('status', sa.String(length=32), nullable=False),
        sa.Column('init_payload', sa.JSON(), nullable=False),
        sa.Column('callback_payload', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('paid_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('issued_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('failure_reason', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_mobile_payments_branch_id'),
        'mobile_payments',
        ['branch_id'],
        unique=False,
    )
    op.create_index(
        op.f('ix_mobile_payments_external_payment_id'),
        'mobile_payments',
        ['external_payment_id'],
        unique=True,
    )
    op.create_index(
        op.f('ix_mobile_payments_local_order_id'),
        'mobile_payments',
        ['local_order_id'],
        unique=True,
    )
    op.create_index(
        op.f('ix_mobile_payments_mobile_user_id'),
        'mobile_payments',
        ['mobile_user_id'],
        unique=False,
    )
    op.create_index(
        op.f('ix_mobile_payments_payable_entity_id'),
        'mobile_payments',
        ['payable_entity_id'],
        unique=False,
    )
    op.create_index(
        op.f('ix_mobile_payments_status'),
        'mobile_payments',
        ['status'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f('ix_mobile_payments_status'), table_name='mobile_payments')
    op.drop_index(op.f('ix_mobile_payments_payable_entity_id'), table_name='mobile_payments')
    op.drop_index(op.f('ix_mobile_payments_mobile_user_id'), table_name='mobile_payments')
    op.drop_index(op.f('ix_mobile_payments_local_order_id'), table_name='mobile_payments')
    op.drop_index(op.f('ix_mobile_payments_external_payment_id'), table_name='mobile_payments')
    op.drop_index(op.f('ix_mobile_payments_branch_id'), table_name='mobile_payments')
    op.drop_table('mobile_payments')
