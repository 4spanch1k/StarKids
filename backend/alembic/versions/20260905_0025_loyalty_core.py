"""Add configurable loyalty ledger core."""

from alembic import op
import sqlalchemy as sa

revision = '20260905_0025'
down_revision = '20260903_0024'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'loyalty_settings',
        sa.Column('id', sa.SmallInteger(), nullable=False, server_default='1'),
        sa.Column('max_redemption_percent', sa.Numeric(5, 2), nullable=False, server_default='0'),
        sa.Column('bonus_value_kzt', sa.Numeric(12, 4), nullable=False, server_default='1'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.CheckConstraint('id = 1', name='ck_loyalty_settings_singleton'),
        sa.CheckConstraint('max_redemption_percent >= 0 AND max_redemption_percent <= 100', name='ck_loyalty_settings_max_redemption_percent'),
        sa.CheckConstraint('bonus_value_kzt > 0', name='ck_loyalty_settings_bonus_value_positive'),
    )
    op.execute("INSERT INTO loyalty_settings (id, max_redemption_percent, bonus_value_kzt) VALUES (1, 0, 1)")
    op.create_table(
        'loyalty_accounts',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('balance', sa.BigInteger(), nullable=False, server_default='0'),
        sa.Column('reserved_balance', sa.BigInteger(), nullable=False, server_default='0'),
        sa.Column('lifetime_earned', sa.BigInteger(), nullable=False, server_default='0'),
        sa.Column('lifetime_spent', sa.BigInteger(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('mobile_user_id', name='uq_loyalty_accounts_mobile_user_id'),
        sa.CheckConstraint('balance >= 0', name='ck_loyalty_accounts_balance_nonnegative'),
        sa.CheckConstraint('reserved_balance >= 0', name='ck_loyalty_accounts_reserved_nonnegative'),
        sa.CheckConstraint('reserved_balance <= balance', name='ck_loyalty_accounts_reserved_le_balance'),
    )
    op.create_index('ix_loyalty_accounts_mobile_user_id', 'loyalty_accounts', ['mobile_user_id'], unique=False)
    op.create_table(
        'loyalty_rules',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('event_type', sa.String(length=32), nullable=False),
        sa.Column('reward_type', sa.String(length=16), nullable=False),
        sa.Column('value', sa.Numeric(12, 4), nullable=False, server_default='0'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('starts_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('ends_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_loyalty_rules_event_type', 'loyalty_rules', ['event_type'], unique=False)
    op.create_index('ix_loyalty_rules_is_active', 'loyalty_rules', ['is_active'], unique=False)
    op.create_table(
        'loyalty_transactions',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('mobile_user_id', sa.String(length=32), nullable=False),
        sa.Column('account_id', sa.String(length=32), nullable=False),
        sa.Column('type', sa.String(length=16), nullable=False),
        sa.Column('amount', sa.BigInteger(), nullable=False),
        sa.Column('balance_delta', sa.BigInteger(), nullable=False, server_default='0'),
        sa.Column('reserved_delta', sa.BigInteger(), nullable=False, server_default='0'),
        sa.Column('source_type', sa.String(length=32), nullable=False),
        sa.Column('source_id', sa.String(length=128), nullable=False),
        sa.Column('idempotency_key', sa.String(length=191), nullable=False),
        sa.Column('status', sa.String(length=16), nullable=False, server_default='posted'),
        sa.Column('description', sa.String(length=255), nullable=True),
        sa.Column('metadata_json', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['mobile_user_id'], ['mobile_users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['account_id'], ['loyalty_accounts.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('idempotency_key', name='uq_loyalty_transactions_idempotency_key'),
        sa.UniqueConstraint('type', 'source_type', 'source_id', name='uq_loyalty_transactions_event_source'),
    )
    op.create_index('ix_loyalty_transactions_mobile_user_id', 'loyalty_transactions', ['mobile_user_id'], unique=False)
    op.create_index('ix_loyalty_transactions_account_id', 'loyalty_transactions', ['account_id'], unique=False)
    op.create_index('ix_loyalty_transactions_user_created', 'loyalty_transactions', ['mobile_user_id', 'created_at'], unique=False)
    op.create_index('ix_loyalty_transactions_source', 'loyalty_transactions', ['source_type', 'source_id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_loyalty_transactions_source', table_name='loyalty_transactions')
    op.drop_index('ix_loyalty_transactions_user_created', table_name='loyalty_transactions')
    op.drop_index('ix_loyalty_transactions_account_id', table_name='loyalty_transactions')
    op.drop_index('ix_loyalty_transactions_mobile_user_id', table_name='loyalty_transactions')
    op.drop_table('loyalty_transactions')
    op.drop_index('ix_loyalty_rules_is_active', table_name='loyalty_rules')
    op.drop_index('ix_loyalty_rules_event_type', table_name='loyalty_rules')
    op.drop_table('loyalty_rules')
    op.drop_index('ix_loyalty_accounts_mobile_user_id', table_name='loyalty_accounts')
    op.drop_table('loyalty_accounts')
    op.drop_table('loyalty_settings')
