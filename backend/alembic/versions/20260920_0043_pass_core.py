"""Add child passes and generic admission core."""

from alembic import op
import sqlalchemy as sa


revision = '20260920_0043'
down_revision = '20260919_0042'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'mobile_payments',
        sa.Column('pass_issuance_required', sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index('ix_mobile_payments_pass_issuance_required', 'mobile_payments', ['pass_issuance_required'])

    with op.batch_alter_table('visits') as batch:
        batch.alter_column('mobile_payment_id', existing_type=sa.String(length=32), nullable=True)
        batch.add_column(sa.Column('child_id', sa.String(length=32), nullable=True))
        batch.create_foreign_key('fk_visits_child_id_mobile_children', 'mobile_children', ['child_id'], ['id'], ondelete='RESTRICT')
        batch.create_index('ix_visits_child_id', ['child_id'])

    op.create_table(
        'pass_plans',
        sa.Column('id', sa.String(length=32), primary_key=True),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.Column('price_tenge', sa.Integer(), nullable=False),
        sa.Column('visit_limit', sa.Integer(), nullable=False),
        sa.Column('validity_days', sa.Integer(), nullable=False),
        sa.Column('daily_limit', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('branch_id', sa.String(length=32), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.CheckConstraint('price_tenge > 0', name='ck_pass_plans_price_positive'),
        sa.CheckConstraint('visit_limit > 0', name='ck_pass_plans_visit_limit_positive'),
        sa.CheckConstraint('validity_days > 0', name='ck_pass_plans_validity_positive'),
        sa.CheckConstraint('daily_limit >= 1', name='ck_pass_plans_daily_limit_positive'),
    )
    op.create_index('ix_pass_plans_branch_id', 'pass_plans', ['branch_id'])
    op.create_index('ix_pass_plans_is_active', 'pass_plans', ['is_active'])

    op.create_table(
        'customer_passes',
        sa.Column('id', sa.String(length=32), primary_key=True),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('child_id', sa.String(length=32), nullable=False),
        sa.Column('mobile_payment_id', sa.String(length=32), nullable=False),
        sa.Column('pass_plan_id', sa.String(length=32), nullable=False),
        sa.Column('name_snapshot', sa.String(length=120), nullable=False),
        sa.Column('price_tenge_snapshot', sa.Integer(), nullable=False),
        sa.Column('visit_limit_snapshot', sa.Integer(), nullable=False),
        sa.Column('validity_days_snapshot', sa.Integer(), nullable=False),
        sa.Column('daily_limit_snapshot', sa.Integer(), nullable=False),
        sa.Column('branch_id_snapshot', sa.String(length=32), nullable=True),
        sa.Column('activated_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('remaining_visits', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(length=16), nullable=False, server_default='active'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['child_id'], ['mobile_children.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['mobile_payment_id'], ['mobile_payments.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['pass_plan_id'], ['pass_plans.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['branch_id_snapshot'], ['branches.id'], ondelete='RESTRICT'),
        sa.UniqueConstraint('mobile_payment_id', name='uq_customer_passes_mobile_payment_id'),
        sa.CheckConstraint('remaining_visits >= 0', name='ck_customer_passes_remaining_non_negative'),
        sa.CheckConstraint('remaining_visits <= visit_limit_snapshot', name='ck_customer_passes_remaining_within_limit'),
    )
    for name, cols in (
        ('ix_customer_passes_mobile_user_id', ['mobile_user_id']),
        ('ix_customer_passes_child_id', ['child_id']),
        ('ix_customer_passes_mobile_payment_id', ['mobile_payment_id']),
        ('ix_customer_passes_pass_plan_id', ['pass_plan_id']),
        ('ix_customer_passes_branch_id_snapshot', ['branch_id_snapshot']),
        ('ix_customer_passes_expires_at', ['expires_at']),
        ('ix_customer_passes_status', ['status']),
    ):
        op.create_index(name, 'customer_passes', cols)

    op.create_table(
        'pass_redemptions',
        sa.Column('id', sa.String(length=32), primary_key=True),
        sa.Column('customer_pass_id', sa.String(length=32), nullable=False),
        sa.Column('visit_id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('redeemed_by_admin_user_id', sa.String(length=32), nullable=False),
        sa.Column('business_date', sa.Date(), nullable=False),
        sa.Column('redeemed_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('source', sa.String(length=16), nullable=False, server_default='scan'),
        sa.Column('reason', sa.String(length=64), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['customer_pass_id'], ['customer_passes.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['visit_id'], ['visits.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['redeemed_by_admin_user_id'], ['admin_users.id'], ondelete='RESTRICT'),
        sa.UniqueConstraint('customer_pass_id', 'business_date', name='uq_pass_redemptions_pass_business_date'),
    )
    op.create_index('ix_pass_redemptions_branch_id', 'pass_redemptions', ['branch_id'])
    op.create_index('ix_pass_redemptions_visit_id', 'pass_redemptions', ['visit_id'])


def downgrade() -> None:
    op.drop_index('ix_pass_redemptions_visit_id', table_name='pass_redemptions')
    op.drop_index('ix_pass_redemptions_branch_id', table_name='pass_redemptions')
    op.drop_table('pass_redemptions')
    for name in (
        'ix_customer_passes_status', 'ix_customer_passes_expires_at', 'ix_customer_passes_branch_id_snapshot',
        'ix_customer_passes_pass_plan_id', 'ix_customer_passes_mobile_payment_id', 'ix_customer_passes_child_id',
        'ix_customer_passes_mobile_user_id',
    ):
        op.drop_index(name, table_name='customer_passes')
    op.drop_table('customer_passes')
    op.drop_index('ix_pass_plans_is_active', table_name='pass_plans')
    op.drop_index('ix_pass_plans_branch_id', table_name='pass_plans')
    op.drop_table('pass_plans')
    with op.batch_alter_table('visits') as batch:
        batch.drop_index('ix_visits_child_id')
        batch.drop_constraint('fk_visits_child_id_mobile_children', type_='foreignkey')
        batch.drop_column('child_id')
        batch.alter_column('mobile_payment_id', existing_type=sa.String(length=32), nullable=False)
    op.drop_index('ix_mobile_payments_pass_issuance_required', table_name='mobile_payments')
    op.drop_column('mobile_payments', 'pass_issuance_required')
