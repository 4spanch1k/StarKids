"""Add news analytics events table."""

from alembic import op
import sqlalchemy as sa


revision = '20260421_0016'
down_revision = '20260420_0015'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'news_events',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('news_id', sa.String(length=32), nullable=False),
        sa.Column('event_type', sa.String(length=16), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(['news_id'], ['news.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_news_events_created_at'), 'news_events', ['created_at'], unique=False)
    op.create_index(op.f('ix_news_events_event_type'), 'news_events', ['event_type'], unique=False)
    op.create_index(op.f('ix_news_events_news_id'), 'news_events', ['news_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_news_events_news_id'), table_name='news_events')
    op.drop_index(op.f('ix_news_events_event_type'), table_name='news_events')
    op.drop_index(op.f('ix_news_events_created_at'), table_name='news_events')
    op.drop_table('news_events')
