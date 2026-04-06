"""Mobile MVP foundation for branches, birthday packages, and requests."""

from alembic import op
import sqlalchemy as sa


revision = '20260406_0001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'branches',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('slug', sa.String(length=120), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('city', sa.String(length=120), nullable=False),
        sa.Column('address', sa.String(length=255), nullable=False),
        sa.Column('short_label', sa.String(length=120), nullable=False),
        sa.Column('working_hours', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('phone', sa.String(length=32), nullable=False),
        sa.Column('whatsapp_phone', sa.String(length=32), nullable=False),
        sa.Column('hero_image_url', sa.String(length=512), nullable=True),
        sa.Column('gallery_image_urls', sa.JSON(), nullable=False),
        sa.Column('facilities', sa.JSON(), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('slug'),
    )

    op.create_table(
        'birthday_packages',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('slug', sa.String(length=120), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('price_from', sa.Integer(), nullable=False),
        sa.Column('price_label', sa.String(length=64), nullable=False),
        sa.Column('guest_capacity_label', sa.String(length=64), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('highlights', sa.JSON(), nullable=False),
        sa.Column('image_url', sa.String(length=512), nullable=True),
        sa.Column('is_featured', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('slug'),
    )
    op.create_index(
        op.f('ix_birthday_packages_branch_id'),
        'birthday_packages',
        ['branch_id'],
        unique=False,
    )
    op.create_table(
        'birthday_requests',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('branch_id', sa.String(length=32), nullable=False),
        sa.Column('birthday_package_id', sa.String(length=32), nullable=True),
        sa.Column('customer_name', sa.String(length=120), nullable=False),
        sa.Column('phone', sa.String(length=32), nullable=False),
        sa.Column('child_name', sa.String(length=120), nullable=True),
        sa.Column('child_age', sa.Integer(), nullable=True),
        sa.Column('guest_count', sa.Integer(), nullable=True),
        sa.Column('requested_date', sa.Date(), nullable=True),
        sa.Column(
            'contact_method',
            sa.String(length=32),
            nullable=False,
            server_default=sa.text("'phone'"),
        ),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column(
            'source',
            sa.String(length=64),
            nullable=False,
            server_default=sa.text("'mobile_app'"),
        ),
        sa.Column(
            'status',
            sa.String(length=32),
            nullable=False,
            server_default=sa.text("'new'"),
        ),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(['birthday_package_id'], ['birthday_packages.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_birthday_requests_birthday_package_id'),
        'birthday_requests',
        ['birthday_package_id'],
        unique=False,
    )
    op.create_index(
        op.f('ix_birthday_requests_branch_id'),
        'birthday_requests',
        ['branch_id'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f('ix_birthday_requests_branch_id'), table_name='birthday_requests')
    op.drop_index(
        op.f('ix_birthday_requests_birthday_package_id'),
        table_name='birthday_requests',
    )
    op.drop_table('birthday_requests')

    op.drop_index(op.f('ix_birthday_packages_branch_id'), table_name='birthday_packages')
    op.drop_table('birthday_packages')

    op.drop_table('branches')
