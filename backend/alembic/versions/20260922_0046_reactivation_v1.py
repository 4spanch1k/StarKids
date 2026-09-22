"""Add reactivation V1 and generic lifecycle anchor names."""

from alembic import op


revision = '20260922_0046'
down_revision = '20260921_0045'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        'lifecycle_journey_executions',
        'first_visit_id',
        new_column_name='anchor_visit_id',
    )
    op.alter_column(
        'lifecycle_journey_executions',
        'first_visit_at',
        new_column_name='anchor_visit_at',
    )
    op.drop_constraint('ck_push_campaigns_origin', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_origin',
        'push_campaigns',
        "origin IN ('manual', 'system_birthday', 'system_first_to_second_visit', 'system_reactivation')",
    )


def downgrade() -> None:
    op.drop_constraint('ck_push_campaigns_origin', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_origin',
        'push_campaigns',
        "origin IN ('manual', 'system_birthday', 'system_first_to_second_visit')",
    )
    op.alter_column(
        'lifecycle_journey_executions',
        'anchor_visit_at',
        new_column_name='first_visit_at',
    )
    op.alter_column(
        'lifecycle_journey_executions',
        'anchor_visit_id',
        new_column_name='first_visit_id',
    )
