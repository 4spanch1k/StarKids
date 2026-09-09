"""Create individual issued ticket records."""

from alembic import op
import sqlalchemy as sa


revision = '20260831_0020'
down_revision = '20260831_0019'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'issued_tickets',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('mobile_payment_id', sa.String(length=32), nullable=False),
        sa.Column('ticket_number', sa.String(length=32), nullable=False),
        sa.Column('ticket_item_id', sa.String(length=32), nullable=False),
        sa.Column('title_snapshot', sa.String(length=255), nullable=False),
        sa.Column('price_tenge', sa.Integer(), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('visit_date', sa.Date(), nullable=True),
        sa.Column('line_index', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(length=32), nullable=False),
        sa.Column('issued_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ['mobile_payment_id'],
            ['mobile_payments.id'],
            ondelete='CASCADE',
        ),
        sa.ForeignKeyConstraint(
            ['branch_id'],
            ['branches.id'],
            ondelete='RESTRICT',
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('ticket_number', name='uq_issued_tickets_ticket_number'),
        sa.UniqueConstraint(
            'mobile_payment_id',
            'line_index',
            name='uq_issued_tickets_payment_line_index',
        ),
    )
    op.create_index('ix_issued_tickets_payment_id', 'issued_tickets', ['mobile_payment_id'])
    op.create_index('ix_issued_tickets_branch_id', 'issued_tickets', ['branch_id'])
    op.create_index('ix_issued_tickets_status', 'issued_tickets', ['status'])
    op.create_index('ix_issued_tickets_visit_date', 'issued_tickets', ['visit_date'])


def downgrade() -> None:
    op.drop_index('ix_issued_tickets_visit_date', table_name='issued_tickets')
    op.drop_index('ix_issued_tickets_status', table_name='issued_tickets')
    op.drop_index('ix_issued_tickets_branch_id', table_name='issued_tickets')
    op.drop_index('ix_issued_tickets_payment_id', table_name='issued_tickets')
    op.drop_table('issued_tickets')
