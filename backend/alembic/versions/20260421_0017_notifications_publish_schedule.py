"""Add mobile notifications table and news publish scheduling fields."""

from alembic import op
import sqlalchemy as sa


revision = '20260421_0017'
down_revision = '20260421_0016'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'news',
        sa.Column(
            'display_order',
            sa.Integer(),
            nullable=False,
            server_default='0',
        ),
    )
    op.add_column(
        'news',
        sa.Column('publish_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        op.f('ix_news_display_order'),
        'news',
        ['display_order'],
        unique=False,
    )
    op.create_index(
        op.f('ix_news_publish_at'),
        'news',
        ['publish_at'],
        unique=False,
    )

    op.create_table(
        'mobile_notifications',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('news_id', sa.String(length=32), nullable=True),
        sa.Column('notification_type', sa.String(length=16), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('image_url', sa.String(length=512), nullable=True),
        sa.Column(
            'is_active',
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.Column('publish_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(['news_id'], ['news.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('news_id'),
    )
    op.create_index(
        op.f('ix_mobile_notifications_created_at'),
        'mobile_notifications',
        ['created_at'],
        unique=False,
    )
    op.create_index(
        op.f('ix_mobile_notifications_is_active'),
        'mobile_notifications',
        ['is_active'],
        unique=False,
    )
    op.create_index(
        op.f('ix_mobile_notifications_notification_type'),
        'mobile_notifications',
        ['notification_type'],
        unique=False,
    )
    op.create_index(
        op.f('ix_mobile_notifications_publish_at'),
        'mobile_notifications',
        ['publish_at'],
        unique=False,
    )

    op.execute(
        sa.text(
            """
            INSERT INTO mobile_notifications (
                id,
                news_id,
                notification_type,
                title,
                description,
                image_url,
                is_active,
                publish_at,
                created_at
            )
            SELECT
                id,
                id,
                'news',
                title,
                description,
                image_url,
                is_active,
                publish_at,
                created_at
            FROM news
            """
        )
    )

    op.alter_column('news', 'display_order', server_default=None)


def downgrade() -> None:
    op.drop_index(
        op.f('ix_mobile_notifications_publish_at'),
        table_name='mobile_notifications',
    )
    op.drop_index(
        op.f('ix_mobile_notifications_notification_type'),
        table_name='mobile_notifications',
    )
    op.drop_index(
        op.f('ix_mobile_notifications_is_active'),
        table_name='mobile_notifications',
    )
    op.drop_index(
        op.f('ix_mobile_notifications_created_at'),
        table_name='mobile_notifications',
    )
    op.drop_table('mobile_notifications')

    op.drop_index(op.f('ix_news_publish_at'), table_name='news')
    op.drop_index(op.f('ix_news_display_order'), table_name='news')
    op.drop_column('news', 'publish_at')
    op.drop_column('news', 'display_order')
