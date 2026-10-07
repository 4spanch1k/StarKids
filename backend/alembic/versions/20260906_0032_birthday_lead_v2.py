"""Add structured birthday lead v2 fields and idempotency."""

from alembic import op
import sqlalchemy as sa


revision = '20260906_0032'
down_revision = '20260906_0031'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'birthday_requests',
        sa.Column('child_id', sa.String(length=32), nullable=True),
    )
    op.create_foreign_key(
        'fk_birthday_requests_child_id_mobile_children',
        'birthday_requests',
        'mobile_children',
        ['child_id'],
        ['id'],
        ondelete='SET NULL',
    )
    op.create_index('ix_birthday_requests_child_id', 'birthday_requests', ['child_id'])
    op.add_column('birthday_requests', sa.Column('idempotency_key', sa.String(length=128), nullable=True))
    op.add_column('birthday_requests', sa.Column('child_name_snapshot', sa.String(length=120), nullable=True))
    op.add_column('birthday_requests', sa.Column('child_birth_date_snapshot', sa.Date(), nullable=True))
    op.add_column('birthday_requests', sa.Column('package_name_snapshot', sa.String(length=255), nullable=True))
    op.add_column('birthday_requests', sa.Column('package_price_snapshot', sa.Integer(), nullable=True))
    op.add_column('birthday_requests', sa.Column('admin_note', sa.Text(), nullable=True))
    op.add_column(
        'birthday_requests',
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.add_column('birthday_requests', sa.Column('contacted_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('birthday_requests', sa.Column('closed_at', sa.DateTime(timezone=True), nullable=True))
    # Nullable idempotency keys preserve anonymous legacy requests while
    # enforcing one retry-safe key per authenticated user.
    op.create_index(
        'uq_birthday_requests_user_idempotency',
        'birthday_requests',
        ['mobile_user_id', 'idempotency_key'],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index('uq_birthday_requests_user_idempotency', table_name='birthday_requests')
    op.drop_column('birthday_requests', 'closed_at')
    op.drop_column('birthday_requests', 'contacted_at')
    op.drop_column('birthday_requests', 'updated_at')
    op.drop_column('birthday_requests', 'admin_note')
    op.drop_column('birthday_requests', 'package_price_snapshot')
    op.drop_column('birthday_requests', 'package_name_snapshot')
    op.drop_column('birthday_requests', 'child_birth_date_snapshot')
    op.drop_column('birthday_requests', 'child_name_snapshot')
    op.drop_column('birthday_requests', 'idempotency_key')
    op.drop_index('ix_birthday_requests_child_id', table_name='birthday_requests')
    op.drop_constraint('fk_birthday_requests_child_id_mobile_children', 'birthday_requests', type_='foreignkey')
    op.drop_column('birthday_requests', 'child_id')
