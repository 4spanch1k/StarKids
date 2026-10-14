"""Add birthday sales funnel fields."""

from alembic import op
import sqlalchemy as sa


revision = '20260908_0035'
down_revision = '20260907_0034'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'birthday_requests',
        sa.Column('agreed_amount_tenge', sa.Integer(), nullable=True),
    )
    op.add_column(
        'birthday_requests',
        sa.Column('lost_reason', sa.String(length=32), nullable=True),
    )
    op.add_column(
        'birthday_requests',
        sa.Column('qualified_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'birthday_requests',
        sa.Column('booked_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'birthday_requests',
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'birthday_requests',
        sa.Column('lost_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_check_constraint(
        'ck_birthday_requests_agreed_amount_non_negative',
        'birthday_requests',
        'agreed_amount_tenge IS NULL OR agreed_amount_tenge >= 0',
    )


def downgrade() -> None:
    op.drop_constraint(
        'ck_birthday_requests_agreed_amount_non_negative',
        'birthday_requests',
        type_='check',
    )
    op.drop_column('birthday_requests', 'lost_at')
    op.drop_column('birthday_requests', 'completed_at')
    op.drop_column('birthday_requests', 'booked_at')
    op.drop_column('birthday_requests', 'qualified_at')
    op.drop_column('birthday_requests', 'lost_reason')
    op.drop_column('birthday_requests', 'agreed_amount_tenge')
