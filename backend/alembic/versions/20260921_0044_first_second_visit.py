"""Add the first-to-second-visit lifecycle experiment."""

from alembic import op
import sqlalchemy as sa


revision = '20260921_0044'
down_revision = '20260920_0043'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint('ck_push_campaigns_origin', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_origin', 'push_campaigns',
        "origin IN ('manual', 'system_birthday', 'system_first_to_second_visit')",
    )
    op.create_table(
        'lifecycle_journey_executions',
        sa.Column('id', sa.String(length=32), primary_key=True),
        sa.Column('journey_key', sa.String(length=64), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('experiment_group', sa.String(length=16), nullable=False),
        sa.Column('eligible_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('first_visit_id', sa.String(length=32), nullable=False),
        sa.Column('first_visit_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('push_campaign_id', sa.String(length=32), nullable=True),
        sa.Column('push_sent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('converted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('conversion_visit_id', sa.String(length=32), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['first_visit_id'], ['visits.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['push_campaign_id'], ['push_campaigns.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['conversion_visit_id'], ['visits.id'], ondelete='SET NULL'),
        sa.UniqueConstraint('journey_key', 'mobile_user_id', name='uq_lifecycle_journey_user'),
        sa.UniqueConstraint('push_campaign_id', name='uq_lifecycle_journey_campaign'),
        sa.CheckConstraint("experiment_group IN ('control', 'treatment')", name='ck_lifecycle_experiment_group'),
    )
    op.create_index('ix_lifecycle_journey_executions_mobile_user_id', 'lifecycle_journey_executions', ['mobile_user_id'])
    op.create_index('ix_lifecycle_journey_eligible_at', 'lifecycle_journey_executions', ['journey_key', 'eligible_at'])
    op.create_index('ix_lifecycle_journey_campaign', 'lifecycle_journey_executions', ['push_campaign_id'])


def downgrade() -> None:
    op.drop_index('ix_lifecycle_journey_campaign', table_name='lifecycle_journey_executions')
    op.drop_index('ix_lifecycle_journey_eligible_at', table_name='lifecycle_journey_executions')
    op.drop_index('ix_lifecycle_journey_executions_mobile_user_id', table_name='lifecycle_journey_executions')
    op.drop_table('lifecycle_journey_executions')
    op.drop_constraint('ck_push_campaigns_origin', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_origin', 'push_campaigns', "origin IN ('manual', 'system_birthday')",
    )
