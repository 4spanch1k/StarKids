"""Persist contact leads and expose them in the admin inbox."""

from alembic import op
import sqlalchemy as sa


revision = '20260408_0005'
down_revision = '20260408_0004'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'contact_leads',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('customer_name', sa.String(length=120), nullable=False),
        sa.Column('phone', sa.String(length=32), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=True),
        sa.Column('message', sa.Text(), nullable=True),
        sa.Column(
            'source',
            sa.String(length=64),
            nullable=False,
            server_default='mobile_app',
        ),
        sa.Column(
            'status',
            sa.String(length=32),
            nullable=False,
            server_default='new',
        ),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.PrimaryKeyConstraint('id'),
    )


def downgrade() -> None:
    op.drop_table('contact_leads')
