"""Add news system for mobile and admin."""

from alembic import op
import sqlalchemy as sa


revision = '20260420_0015'
down_revision = '20260420_0014'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'news',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('image_url', sa.String(length=512), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column(
            'is_active',
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_news_created_at'), 'news', ['created_at'], unique=False)
    op.create_index(op.f('ix_news_is_active'), 'news', ['is_active'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_news_is_active'), table_name='news')
    op.drop_index(op.f('ix_news_created_at'), table_name='news')
    op.drop_table('news')
