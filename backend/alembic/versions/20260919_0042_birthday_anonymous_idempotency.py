"""Protect anonymous birthday lead idempotency keys from PostgreSQL NULL semantics."""

from alembic import op
import sqlalchemy as sa


revision = '20260919_0042'
down_revision = '20260919_0041'
branch_labels = None
depends_on = None


def _anonymous_duplicate_query() -> sa.Select:
    birthday_requests = sa.table(
        'birthday_requests',
        sa.column('mobile_user_id', sa.String(length=32)),
        sa.column('idempotency_key', sa.String(length=128)),
    )
    return (
        sa.select(birthday_requests.c.idempotency_key)
        .where(
            birthday_requests.c.mobile_user_id.is_(None),
            birthday_requests.c.idempotency_key.is_not(None),
        )
        .group_by(birthday_requests.c.idempotency_key)
        .having(sa.func.count() > 1)
        .limit(1)
    )


def upgrade() -> None:
    bind = op.get_bind()
    duplicate = bind.execute(_anonymous_duplicate_query()).first()
    if duplicate is not None:
        raise RuntimeError(
            'Cannot add anonymous birthday idempotency index: duplicate non-null '
            f'idempotency_key exists ({duplicate[0]!r}). Resolve duplicates before retrying migration.'
        )

    op.create_index(
        'uq_birthday_requests_anonymous_idempotency',
        'birthday_requests',
        ['idempotency_key'],
        unique=True,
        postgresql_where=sa.text('mobile_user_id IS NULL AND idempotency_key IS NOT NULL'),
        sqlite_where=sa.text('mobile_user_id IS NULL AND idempotency_key IS NOT NULL'),
    )


def downgrade() -> None:
    op.drop_index('uq_birthday_requests_anonymous_idempotency', table_name='birthday_requests')
