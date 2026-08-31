"""Create atomic ticket redemption audit records."""

from alembic import op
import sqlalchemy as sa


revision = '20260831_0021'
down_revision = '20260831_0020'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'ticket_redemptions',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('issued_ticket_id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('redeemed_by_admin_user_id', sa.String(length=32), nullable=False),
        sa.Column('redeemed_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ['issued_ticket_id'],
            ['issued_tickets.id'],
            ondelete='CASCADE',
        ),
        sa.ForeignKeyConstraint(
            ['branch_id'],
            ['branches.id'],
            ondelete='RESTRICT',
        ),
        sa.ForeignKeyConstraint(
            ['redeemed_by_admin_user_id'],
            ['admin_users.id'],
            ondelete='RESTRICT',
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'issued_ticket_id',
            name='uq_ticket_redemptions_issued_ticket',
        ),
    )
    op.create_index(
        'ix_ticket_redemptions_branch_id',
        'ticket_redemptions',
        ['branch_id'],
    )
    op.create_index(
        'ix_ticket_redemptions_admin_user_id',
        'ticket_redemptions',
        ['redeemed_by_admin_user_id'],
    )


def downgrade() -> None:
    op.drop_index('ix_ticket_redemptions_admin_user_id', table_name='ticket_redemptions')
    op.drop_index('ix_ticket_redemptions_branch_id', table_name='ticket_redemptions')
    op.drop_table('ticket_redemptions')
