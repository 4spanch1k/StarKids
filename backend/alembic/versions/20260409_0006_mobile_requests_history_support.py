"""Link mobile leads to authenticated users and expose request history."""

from alembic import op
import sqlalchemy as sa


revision = '20260409_0006'
down_revision = '20260408_0005'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'birthday_requests',
        sa.Column('mobile_user_id', sa.String(length=32), nullable=True),
    )
    op.create_index(
        op.f('ix_birthday_requests_mobile_user_id'),
        'birthday_requests',
        ['mobile_user_id'],
        unique=False,
    )
    op.create_foreign_key(
        'fk_birthday_requests_mobile_user_id_mobile_users',
        'birthday_requests',
        'mobile_users',
        ['mobile_user_id'],
        ['id'],
        ondelete='SET NULL',
    )

    op.add_column(
        'contact_leads',
        sa.Column('mobile_user_id', sa.String(length=32), nullable=True),
    )
    op.create_index(
        op.f('ix_contact_leads_mobile_user_id'),
        'contact_leads',
        ['mobile_user_id'],
        unique=False,
    )
    op.create_foreign_key(
        'fk_contact_leads_mobile_user_id_mobile_users',
        'contact_leads',
        'mobile_users',
        ['mobile_user_id'],
        ['id'],
        ondelete='SET NULL',
    )


def downgrade() -> None:
    op.drop_constraint(
        'fk_contact_leads_mobile_user_id_mobile_users',
        'contact_leads',
        type_='foreignkey',
    )
    op.drop_index(op.f('ix_contact_leads_mobile_user_id'), table_name='contact_leads')
    op.drop_column('contact_leads', 'mobile_user_id')

    op.drop_constraint(
        'fk_birthday_requests_mobile_user_id_mobile_users',
        'birthday_requests',
        type_='foreignkey',
    )
    op.drop_index(op.f('ix_birthday_requests_mobile_user_id'), table_name='birthday_requests')
    op.drop_column('birthday_requests', 'mobile_user_id')
