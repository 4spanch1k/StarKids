"""Add branch ticket management tables."""

from alembic import op
import sqlalchemy as sa


revision = '20260412_0009'
down_revision = '20260411_0008'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'branch_ticket_items',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('price_tenge', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('badge_labels', sa.JSON(), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_branch_ticket_items_branch_id'),
        'branch_ticket_items',
        ['branch_id'],
        unique=False,
    )

    op.create_table(
        'branch_ticket_notes',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('text', sa.Text(), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_branch_ticket_notes_branch_id'),
        'branch_ticket_notes',
        ['branch_id'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f('ix_branch_ticket_notes_branch_id'), table_name='branch_ticket_notes')
    op.drop_table('branch_ticket_notes')
    op.drop_index(op.f('ix_branch_ticket_items_branch_id'), table_name='branch_ticket_items')
    op.drop_table('branch_ticket_items')
