"""Add an optional branch assignment to admin users."""

from alembic import op
import sqlalchemy as sa


revision = '20260907_0034'
down_revision = '20260906_0033'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'admin_users',
        sa.Column('branch_id', sa.String(length=32), nullable=True),
    )
    op.create_foreign_key(
        'fk_admin_users_branch_id_branches',
        'admin_users',
        'branches',
        ['branch_id'],
        ['id'],
        ondelete='SET NULL',
    )
    op.create_index('ix_admin_users_branch_id', 'admin_users', ['branch_id'])


def downgrade() -> None:
    op.drop_index('ix_admin_users_branch_id', table_name='admin_users')
    op.drop_constraint('fk_admin_users_branch_id_branches', 'admin_users', type_='foreignkey')
    op.drop_column('admin_users', 'branch_id')
