"""Optional PostgreSQL integration proof for loyalty locking.

Run with LOYALTY_POSTGRES_URL pointing at a disposable database already at
Alembic head. It is skipped in the normal SQLite unit-test suite.
"""

from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
import os
from threading import Barrier
import unittest
from uuid import uuid4

from sqlalchemy import create_engine, delete
from sqlalchemy.orm import Session

from app.db.models.loyalty_account import LoyaltyAccount
from app.db.models.loyalty_rule import LoyaltyRule
from app.db.models.loyalty_settings import LoyaltySettings
from app.db.models.loyalty_transaction import LoyaltyTransaction
from app.db.models.mobile_user import MobileUser
from app.db.repositories.loyalty_repository import LoyaltyRepository
from app.modules.loyalty.service import LoyaltyService


@unittest.skipUnless(os.getenv('LOYALTY_POSTGRES_URL'), 'LOYALTY_POSTGRES_URL is not configured')
class LoyaltyPostgresConcurrencyTests(unittest.TestCase):
    def test_concurrent_reserve_allows_only_one_spend(self) -> None:
        engine = create_engine(os.environ['LOYALTY_POSTGRES_URL'], pool_size=6, max_overflow=0)
        email = f'loyalty-pg-test-{uuid4().hex}@example.com'
        with Session(engine) as session:
            user = MobileUser(email=email)
            session.add(user)
            session.flush()
            user_id = user.id
            rule = LoyaltyRule(event_type='registration', reward_type='fixed', value=Decimal('5000'), is_active=True)
            session.add(rule)
            session.flush()
            rule_id = rule.id
            settings = session.get(LoyaltySettings, 1)
            if settings is None:
                session.add(LoyaltySettings(id=1, max_redemption_percent=Decimal('100'), bonus_value_kzt=Decimal('1')))
            else:
                settings.max_redemption_percent = Decimal('100')
            session.commit()

        try:
            with Session(engine) as session:
                LoyaltyService(LoyaltyRepository(session)).apply_event(
                    user_id=user_id,
                    event_type='registration',
                    source_type='test',
                    source_id=f'seed-{user_id}',
                    cash_amount_kzt=None,
                    idempotency_key=f'seed-{user_id}',
                )
                session.commit()

            barrier = Barrier(2)

            def reserve(index: int) -> bool:
                with Session(engine) as session:
                    service = LoyaltyService(LoyaltyRepository(session))
                    barrier.wait()
                    try:
                        service.reserve(
                            user_id=user_id,
                            amount=4000,
                            source_type='test',
                            source_id=f'reserve-{user_id}-{index}',
                            idempotency_key=f'reserve-{user_id}-{index}',
                        )
                        session.commit()
                        return True
                    except Exception:
                        session.rollback()
                        return False

            with ThreadPoolExecutor(max_workers=2) as executor:
                outcomes = list(executor.map(reserve, (1, 2)))
            self.assertEqual(sum(outcomes), 1)
        finally:
            with Session(engine) as session:
                account = session.query(LoyaltyAccount).filter_by(mobile_user_id=user_id).one_or_none()
                session.execute(delete(LoyaltyTransaction).where(LoyaltyTransaction.mobile_user_id == user_id))
                if account is not None:
                    session.delete(account)
                session.delete(session.get(MobileUser, user_id))
                rule_to_delete = session.get(LoyaltyRule, rule_id)
                if rule_to_delete is not None:
                    session.delete(rule_to_delete)
                session.commit()
            engine.dispose()
