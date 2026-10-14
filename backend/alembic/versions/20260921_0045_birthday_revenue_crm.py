"""Add durable birthday revenue cycles and validated lead attribution."""

from alembic import op
import sqlalchemy as sa


revision = '20260921_0045'
down_revision = '20260921_0044'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'birthday_revenue_cycles',
        sa.Column('id', sa.String(length=32), primary_key=True),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('birthday_year', sa.Integer(), nullable=False),
        sa.Column('target_date', sa.Date(), nullable=False),
        sa.Column('experiment_group', sa.String(length=16), nullable=False),
        sa.Column('eligible_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.UniqueConstraint(
            'mobile_user_id', 'birthday_year', 'target_date',
            name='uq_birthday_revenue_cycle_family_occurrence',
        ),
        sa.CheckConstraint(
            "experiment_group IN ('control', 'treatment')",
            name='ck_birthday_revenue_cycle_experiment_group',
        ),
    )
    op.create_index('ix_birthday_revenue_cycles_user', 'birthday_revenue_cycles', ['mobile_user_id'])
    op.create_index('ix_birthday_revenue_cycles_target', 'birthday_revenue_cycles', ['target_date'])

    with op.batch_alter_table('birthday_reminders') as batch:
        batch.drop_constraint('ck_birthday_reminders_days_before', type_='check')
        batch.create_check_constraint(
            'ck_birthday_reminders_days_before',
            'days_before IN (30, 14, 7, 1)',
        )
        batch.add_column(sa.Column('birthday_cycle_id', sa.String(length=32), nullable=True))
        batch.create_foreign_key(
            'fk_birthday_reminders_cycle',
            'birthday_revenue_cycles',
            ['birthday_cycle_id'], ['id'], ondelete='SET NULL',
        )
        batch.create_index('ix_birthday_reminders_birthday_cycle_id', ['birthday_cycle_id'])

    with op.batch_alter_table('birthday_requests') as batch:
        batch.add_column(sa.Column('birthday_cycle_id', sa.String(length=32), nullable=True))
        batch.add_column(sa.Column('source_campaign_id', sa.String(length=32), nullable=True))
        batch.create_foreign_key(
            'fk_birthday_requests_cycle',
            'birthday_revenue_cycles',
            ['birthday_cycle_id'], ['id'], ondelete='SET NULL',
        )
        batch.create_foreign_key(
            'fk_birthday_requests_source_campaign',
            'push_campaigns',
            ['source_campaign_id'], ['id'], ondelete='SET NULL',
        )
        batch.create_index('ix_birthday_requests_birthday_cycle_id', ['birthday_cycle_id'])
        batch.create_index('ix_birthday_requests_source_campaign_id', ['source_campaign_id'])


def downgrade() -> None:
    with op.batch_alter_table('birthday_requests') as batch:
        batch.drop_index('ix_birthday_requests_source_campaign_id')
        batch.drop_index('ix_birthday_requests_birthday_cycle_id')
        batch.drop_constraint('fk_birthday_requests_source_campaign', type_='foreignkey')
        batch.drop_constraint('fk_birthday_requests_cycle', type_='foreignkey')
        batch.drop_column('source_campaign_id')
        batch.drop_column('birthday_cycle_id')

    with op.batch_alter_table('birthday_reminders') as batch:
        batch.drop_index('ix_birthday_reminders_birthday_cycle_id')
        batch.drop_constraint('fk_birthday_reminders_cycle', type_='foreignkey')
        batch.drop_column('birthday_cycle_id')
        batch.drop_constraint('ck_birthday_reminders_days_before', type_='check')
        batch.create_check_constraint(
            'ck_birthday_reminders_days_before',
            'days_before IN (14, 7, 1)',
        )

    op.drop_index('ix_birthday_revenue_cycles_target', table_name='birthday_revenue_cycles')
    op.drop_index('ix_birthday_revenue_cycles_user', table_name='birthday_revenue_cycles')
    op.drop_table('birthday_revenue_cycles')
