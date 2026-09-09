"""Create physical visits and link ticket redemptions to them."""

from alembic import op
import sqlalchemy as sa


revision = '20260903_0022'
down_revision = '20260831_0021'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'visits',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('mobile_payment_id', sa.String(length=32), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('status', sa.String(length=32), server_default='active', nullable=False),
        sa.Column('started_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('ended_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['mobile_payment_id'], ['mobile_payments.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('mobile_payment_id', name='uq_visits_mobile_payment_id'),
    )
    op.create_index('ix_visits_mobile_user_status', 'visits', ['mobile_user_id', 'status'])
    op.create_index('ix_visits_branch_started_at', 'visits', ['branch_id', 'started_at'])
    op.add_column('ticket_redemptions', sa.Column('visit_id', sa.String(length=32), nullable=True))
    op.create_foreign_key(
        'fk_ticket_redemptions_visit_id',
        'ticket_redemptions',
        'visits',
        ['visit_id'],
        ['id'],
        ondelete='RESTRICT',
    )
    op.create_index('ix_ticket_redemptions_visit_id', 'ticket_redemptions', ['visit_id'])


def downgrade() -> None:
    op.drop_index('ix_ticket_redemptions_visit_id', table_name='ticket_redemptions')
    op.drop_constraint('fk_ticket_redemptions_visit_id', 'ticket_redemptions', type_='foreignkey')
    op.drop_column('ticket_redemptions', 'visit_id')
    op.drop_index('ix_visits_branch_started_at', table_name='visits')
    op.drop_index('ix_visits_mobile_user_status', table_name='visits')
    op.drop_table('visits')
