"""Harden loyalty economics and keep one bonus equal to one KZT."""

from alembic import op


revision = '20260905_0026'
down_revision = '20260905_0025'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint('ck_loyalty_settings_bonus_value_positive', 'loyalty_settings', type_='check')
    op.create_check_constraint(
        'ck_loyalty_settings_bonus_value_kzt_one',
        'loyalty_settings',
        'bonus_value_kzt = 1',
    )


def downgrade() -> None:
    op.drop_constraint('ck_loyalty_settings_bonus_value_kzt_one', 'loyalty_settings', type_='check')
    op.create_check_constraint(
        'ck_loyalty_settings_bonus_value_positive',
        'loyalty_settings',
        'bonus_value_kzt > 0',
    )
