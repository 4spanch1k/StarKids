"""Backend content API foundation for admin CRUD and mobile content reads."""

from alembic import op
import sqlalchemy as sa


revision = '20260407_0003'
down_revision = '20260407_0002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('branches', sa.Column('map_url', sa.String(length=1024), nullable=True))
    op.add_column('branches', sa.Column('route_label', sa.String(length=255), nullable=True))
    op.add_column('branches', sa.Column('parking_hint', sa.Text(), nullable=True))
    op.add_column('branches', sa.Column('arrival_hint', sa.Text(), nullable=True))

    op.create_table(
        'branch_pricing_profiles',
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('intro_title', sa.String(length=255), nullable=False),
        sa.Column('intro_description', sa.Text(), nullable=False),
        sa.Column('birthday_note', sa.Text(), nullable=False),
        sa.Column('disclaimer', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('branch_id'),
    )

    op.create_table(
        'branch_tariffs',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('price_label', sa.String(length=64), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_branch_tariffs_branch_id'), 'branch_tariffs', ['branch_id'], unique=False)

    op.create_table(
        'branch_rules',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('text', sa.Text(), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_branch_rules_branch_id'), 'branch_rules', ['branch_id'], unique=False)

    op.create_table(
        'promotions',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('badge_label', sa.String(length=64), nullable=False),
        sa.Column('image_url', sa.String(length=512), nullable=True),
        sa.Column('cta_label', sa.String(length=64), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('is_published', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'promotion_branches',
        sa.Column('promotion_id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['promotion_id'], ['promotions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('promotion_id', 'branch_id'),
    )

    op.create_table(
        'faq_entries',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('question', sa.String(length=255), nullable=False),
        sa.Column('answer', sa.Text(), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('is_published', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'content_blocks',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('surface', sa.String(length=64), nullable=False),
        sa.Column('key', sa.String(length=64), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('body', sa.Text(), nullable=False),
        sa.Column('cta_label', sa.String(length=64), nullable=True),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('is_published', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('surface', 'key', name='uq_content_blocks_surface_key'),
    )


def downgrade() -> None:
    op.drop_table('content_blocks')
    op.drop_table('faq_entries')
    op.drop_table('promotion_branches')
    op.drop_table('promotions')

    op.drop_index(op.f('ix_branch_rules_branch_id'), table_name='branch_rules')
    op.drop_table('branch_rules')

    op.drop_index(op.f('ix_branch_tariffs_branch_id'), table_name='branch_tariffs')
    op.drop_table('branch_tariffs')

    op.drop_table('branch_pricing_profiles')

    op.drop_column('branches', 'arrival_hint')
    op.drop_column('branches', 'parking_hint')
    op.drop_column('branches', 'route_label')
    op.drop_column('branches', 'map_url')
