"""Add branch menu management tables."""

from alembic import op
import sqlalchemy as sa


revision = '20260411_0008'
down_revision = '20260409_0007'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'branch_menu_categories',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('key', sa.String(length=64), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column(
            'display_order',
            sa.Integer(),
            nullable=False,
            server_default='0',
        ),
        sa.Column(
            'is_active',
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'branch_id',
            'key',
            name='uq_branch_menu_categories_branch_key',
        ),
    )
    op.create_index(
        op.f('ix_branch_menu_categories_branch_id'),
        'branch_menu_categories',
        ['branch_id'],
        unique=False,
    )

    op.create_table(
        'branch_menu_items',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('category_id', sa.String(length=32), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column(
            'price_tenge',
            sa.Integer(),
            nullable=False,
            server_default='0',
        ),
        sa.Column('image_url', sa.String(length=1024), nullable=False),
        sa.Column(
            'display_order',
            sa.Integer(),
            nullable=False,
            server_default='0',
        ),
        sa.Column(
            'is_active',
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.ForeignKeyConstraint(
            ['branch_id'],
            ['branches.id'],
            ondelete='CASCADE',
        ),
        sa.ForeignKeyConstraint(
            ['category_id'],
            ['branch_menu_categories.id'],
            ondelete='CASCADE',
        ),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_branch_menu_items_branch_id'),
        'branch_menu_items',
        ['branch_id'],
        unique=False,
    )
    op.create_index(
        op.f('ix_branch_menu_items_category_id'),
        'branch_menu_items',
        ['category_id'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f('ix_branch_menu_items_category_id'), table_name='branch_menu_items')
    op.drop_index(op.f('ix_branch_menu_items_branch_id'), table_name='branch_menu_items')
    op.drop_table('branch_menu_items')
    op.drop_index(
        op.f('ix_branch_menu_categories_branch_id'),
        table_name='branch_menu_categories',
    )
    op.drop_table('branch_menu_categories')
