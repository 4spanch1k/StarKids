from datetime import UTC, datetime

from sqlalchemy import select

from ..models.loyalty_account import LoyaltyAccount
from ..models.loyalty_rule import LoyaltyRule
from ..models.loyalty_transaction import LoyaltyTransaction
from ..models.loyalty_settings import LoyaltySettings
from .base import Repository


class LoyaltyRepository(Repository):
    def get_settings(self, *, for_update: bool = False) -> LoyaltySettings | None:
        statement = select(LoyaltySettings).where(LoyaltySettings.id == 1)
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def get_account(self, user_id: str, *, for_update: bool = False) -> LoyaltyAccount | None:
        statement = select(LoyaltyAccount).where(LoyaltyAccount.mobile_user_id == user_id)
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def get_transaction_by_idempotency(self, key: str, *, for_update: bool = False) -> LoyaltyTransaction | None:
        statement = select(LoyaltyTransaction).where(LoyaltyTransaction.idempotency_key == key)
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def get_transaction(self, transaction_id: str, *, for_update: bool = False) -> LoyaltyTransaction | None:
        statement = select(LoyaltyTransaction).where(LoyaltyTransaction.id == transaction_id)
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def get_by_event_source(self, transaction_type: str, source_type: str, source_id: str) -> LoyaltyTransaction | None:
        return self.db.scalar(select(LoyaltyTransaction).where(LoyaltyTransaction.type == transaction_type, LoyaltyTransaction.source_type == source_type, LoyaltyTransaction.source_id == source_id))

    def list_transactions(self, user_id: str, *, limit: int, offset: int) -> list[LoyaltyTransaction]:
        statement = (
            select(LoyaltyTransaction)
            .where(LoyaltyTransaction.mobile_user_id == user_id)
            .order_by(LoyaltyTransaction.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(self.db.scalars(statement))

    def count_transactions(self, user_id: str) -> int:
        from sqlalchemy import func
        return int(self.db.scalar(select(func.count()).select_from(LoyaltyTransaction).where(LoyaltyTransaction.mobile_user_id == user_id)) or 0)

    def active_rule(self, event_type: str, *, now: datetime | None = None) -> LoyaltyRule | None:
        now = now or datetime.now(UTC)
        statement = (
            select(LoyaltyRule)
            .where(
                LoyaltyRule.event_type == event_type,
                LoyaltyRule.is_active.is_(True),
                (LoyaltyRule.starts_at.is_(None) | (LoyaltyRule.starts_at <= now)),
                (LoyaltyRule.ends_at.is_(None) | (LoyaltyRule.ends_at > now)),
            )
            .order_by(LoyaltyRule.created_at.desc())
            .limit(1)
        )
        return self.db.scalar(statement)

    def list_rules(self) -> list[LoyaltyRule]:
        return list(self.db.scalars(select(LoyaltyRule).order_by(LoyaltyRule.event_type, LoyaltyRule.created_at.desc())))

    def get_rule(self, rule_id: str) -> LoyaltyRule | None:
        return self.db.get(LoyaltyRule, rule_id)
