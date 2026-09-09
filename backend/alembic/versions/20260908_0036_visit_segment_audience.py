"""Allow manual push campaigns to target derived visit segments."""

from alembic import op


revision = '20260908_0036'
down_revision = '20260908_0035'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint('ck_push_campaigns_audience_type', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_audience_type',
        'push_campaigns',
        "audience_type IN ('all_users', 'birthday_in_days', 'user', 'visit_segment')",
    )


def downgrade() -> None:
    op.drop_constraint('ck_push_campaigns_audience_type', 'push_campaigns', type_='check')
    op.create_check_constraint(
        'ck_push_campaigns_audience_type',
        'push_campaigns',
        "audience_type IN ('all_users', 'birthday_in_days', 'user')",
    )
