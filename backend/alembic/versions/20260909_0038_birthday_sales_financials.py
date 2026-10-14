"""Add birthday sales financial tracking fields."""

from alembic import op
import sqlalchemy as sa


revision = '20260909_0038'
down_revision = '20260908_0037'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'birthday_requests',
        sa.Column('expected_amount_tenge', sa.Integer(), nullable=True),
    )
    op.add_column(
        'birthday_requests',
        sa.Column('deposit_amount_tenge', sa.Integer(), nullable=True),
    )
    op.add_column(
        'birthday_requests',
        sa.Column('paid_amount_tenge', sa.Integer(), nullable=True),
    )
    op.add_column(
        'birthday_requests',
        sa.Column('paid_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_check_constraint(
        'ck_birthday_requests_expected_amount_non_negative',
        'birthday_requests',
        'expected_amount_tenge IS NULL OR expected_amount_tenge >= 0',
    )
    op.create_check_constraint(
        'ck_birthday_requests_deposit_amount_non_negative',
        'birthday_requests',
        'deposit_amount_tenge IS NULL OR deposit_amount_tenge >= 0',
    )
    op.create_check_constraint(
        'ck_birthday_requests_paid_amount_non_negative',
        'birthday_requests',
        'paid_amount_tenge IS NULL OR paid_amount_tenge >= 0',
    )


def downgrade() -> None:
    op.drop_constraint(
        'ck_birthday_requests_paid_amount_non_negative',
        'birthday_requests',
        type_='check',
    )
    op.drop_constraint(
        'ck_birthday_requests_deposit_amount_non_negative',
        'birthday_requests',
        type_='check',
    )
    op.drop_constraint(
        'ck_birthday_requests_expected_amount_non_negative',
        'birthday_requests',
        type_='check',
    )
    op.drop_column('birthday_requests', 'paid_at')
    op.drop_column('birthday_requests', 'paid_amount_tenge')
    op.drop_column('birthday_requests', 'deposit_amount_tenge')
    op.drop_column('birthday_requests', 'expected_amount_tenge')
