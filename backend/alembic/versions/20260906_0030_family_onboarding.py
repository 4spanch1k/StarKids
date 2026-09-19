"""Add family onboarding state and complete child timestamps."""

from alembic import op
import sqlalchemy as sa


revision = '20260906_0030'
down_revision = '20260906_0029'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'mobile_users',
        sa.Column('onboarding_completed_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'mobile_users',
        sa.Column('privacy_consent_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'mobile_users',
        sa.Column('privacy_consent_version', sa.String(length=64), nullable=True),
    )
    # Existing accounts with an established parent name predate this flow.
    # Treat those accounts as legacy-complete, while leaving accounts without
    # a parent name eligible for the new setup instead of blocking everyone.
    op.execute(
        sa.text(
            'UPDATE mobile_users '
            'SET onboarding_completed_at = created_at '
            'WHERE onboarding_completed_at IS NULL '
            "AND first_name IS NOT NULL AND trim(first_name) <> ''"
        )
    )
    with op.batch_alter_table('mobile_children') as batch_op:
        batch_op.alter_column(
            'gender',
            existing_type=sa.String(length=10),
            type_=sa.String(length=16),
            existing_nullable=False,
        )
    op.add_column(
        'mobile_children',
        sa.Column(
            'updated_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_column('mobile_children', 'updated_at')
    with op.batch_alter_table('mobile_children') as batch_op:
        batch_op.alter_column(
            'gender',
            existing_type=sa.String(length=16),
            type_=sa.String(length=10),
            existing_nullable=False,
        )
    op.drop_column('mobile_users', 'privacy_consent_version')
    op.drop_column('mobile_users', 'privacy_consent_at')
    op.drop_column('mobile_users', 'onboarding_completed_at')
