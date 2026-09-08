"""Store authenticated push campaign opens."""

from alembic import op
import sqlalchemy as sa


revision = '20260908_0037'
down_revision = '20260908_0036'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'push_campaign_opens',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('campaign_id', sa.String(length=32), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('opened_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['campaign_id'], ['push_campaigns.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('campaign_id', 'mobile_user_id', name='uq_push_campaign_opens_campaign_user'),
    )
    op.create_index('ix_push_campaign_opens_campaign_id', 'push_campaign_opens', ['campaign_id'])
    op.create_index('ix_push_campaign_opens_mobile_user_id', 'push_campaign_opens', ['mobile_user_id'])
    op.create_index('ix_push_campaign_opens_opened_at', 'push_campaign_opens', ['opened_at'])


def downgrade() -> None:
    op.drop_index('ix_push_campaign_opens_opened_at', table_name='push_campaign_opens')
    op.drop_index('ix_push_campaign_opens_mobile_user_id', table_name='push_campaign_opens')
    op.drop_index('ix_push_campaign_opens_campaign_id', table_name='push_campaign_opens')
    op.drop_table('push_campaign_opens')
