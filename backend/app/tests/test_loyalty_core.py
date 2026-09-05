from datetime import UTC, datetime, timedelta
from decimal import Decimal
import unittest

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.models import Base
from app.db.models.loyalty_rule import LoyaltyRule
from app.db.models.loyalty_transaction import LoyaltyTransaction
from app.db.models.loyalty_settings import LoyaltySettings
from app.db.models.mobile_user import MobileUser
from app.modules.loyalty.service import LoyaltyService
from app.db.repositories.loyalty_repository import LoyaltyRepository


class LoyaltyCoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine('sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
        cls.SessionLocal = sessionmaker(bind=cls.engine, autoflush=False, expire_on_commit=False, class_=Session)
        Base.metadata.create_all(cls.engine)

    @classmethod
    def tearDownClass(cls) -> None:
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(LoyaltyTransaction).delete()
            session.query(LoyaltyRule).delete()
            session.query(LoyaltySettings).delete()
            session.query(MobileUser).delete()
            session.commit()

    def _user(self) -> str:
        with self.SessionLocal() as session:
            user = MobileUser(email='loyalty@example.com')
            session.add(user)
            session.commit()
            return user.id

    def test_defaults_do_not_create_rewards(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            service = LoyaltyService(LoyaltyRepository(session))
            self.assertIsNone(service.apply_event(user_id=user_id, event_type='ticket_purchase', source_type='payment', source_id='p1', cash_amount_kzt=10000, idempotency_key='ticket_purchase:p1'))
            self.assertEqual(service.account_response(user_id)['balance'], 0)

    def test_active_percent_rule_is_idempotent(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add(LoyaltyRule(event_type='ticket_purchase', reward_type='percent', value=Decimal('5'), is_active=True))
            session.commit()
            service = LoyaltyService(LoyaltyRepository(session))
            first = service.apply_event(user_id=user_id, event_type='ticket_purchase', source_type='payment', source_id='p1', cash_amount_kzt=10000, idempotency_key='ticket_purchase:p1')
            second = service.apply_event(user_id=user_id, event_type='ticket_purchase', source_type='payment', source_id='p1', cash_amount_kzt=10000, idempotency_key='ticket_purchase:p1')
            third = service.apply_event(user_id=user_id, event_type='ticket_purchase', source_type='payment', source_id='p1', cash_amount_kzt=10000, idempotency_key='ticket_purchase:p1:retry')
            session.commit()
            self.assertIsNotNone(first)
            self.assertEqual(first.id, second.id)
            self.assertEqual(first.id, third.id)
            self.assertEqual(service.account_response(user_id)['balance'], 500)

    def test_reserve_capture_release_and_reversal(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add(LoyaltyRule(event_type='registration', reward_type='fixed', value=Decimal('500'), is_active=True))
            session.commit()
            service = LoyaltyService(LoyaltyRepository(session))
            earned = service.apply_event(user_id=user_id, event_type='registration', source_type='user', source_id=user_id, cash_amount_kzt=None, idempotency_key=f'registration:{user_id}')
            reservation = service.reserve(user_id=user_id, amount=300, source_type='payment', source_id='p2', idempotency_key='reserve:p2')
            self.assertEqual(service.reserve(user_id=user_id, amount=300, source_type='payment', source_id='p2', idempotency_key='reserve:p2:retry').id, reservation.id)
            self.assertEqual(service.account_response(user_id)['availableBalance'], 200)
            service.release(user_id=user_id, reservation_id=reservation.id, idempotency_key='release:p2')
            self.assertEqual(service.account_response(user_id)['availableBalance'], 500)
            service.reverse(user_id=user_id, original_transaction_id=earned.id, idempotency_key='reverse:registration')
            self.assertEqual(service.account_response(user_id)['balance'], 0)
            earned2 = service.apply_event(user_id=user_id, event_type='registration', source_type='user', source_id='second-registration', cash_amount_kzt=None, idempotency_key='registration:second')
            self.assertIsNotNone(earned2)
            reservation2 = service.reserve(user_id=user_id, amount=300, source_type='payment', source_id='p3', idempotency_key='reserve:p3')
            service.capture(user_id=user_id, reservation_id=reservation2.id, idempotency_key='capture:p3')
            self.assertEqual(service.account_response(user_id)['balance'], 200)
            session.commit()

    def test_rule_period_is_respected(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add(LoyaltyRule(event_type='ticket_purchase', reward_type='fixed', value=Decimal('500'), is_active=True, ends_at=datetime.now(UTC) - timedelta(minutes=1)))
            session.commit()
            service = LoyaltyService(LoyaltyRepository(session))
            self.assertIsNone(service.apply_event(user_id=user_id, event_type='ticket_purchase', source_type='payment', source_id='expired', cash_amount_kzt=1000, idempotency_key='ticket_purchase:expired'))

    def test_redemption_limit_is_backend_enforced(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add(LoyaltySettings(id=1, max_redemption_percent=Decimal('30'), bonus_value_kzt=Decimal('1')))
            session.add(LoyaltyRule(event_type='registration', reward_type='fixed', value=Decimal('5000'), is_active=True))
            session.commit()
            service = LoyaltyService(LoyaltyRepository(session))
            service.apply_event(user_id=user_id, event_type='registration', source_type='user', source_id=user_id, cash_amount_kzt=None, idempotency_key=f'registration:{user_id}')
            with self.assertRaisesRegex(Exception, 'превышает допустимый лимит'):
                service.reserve(user_id=user_id, amount=4000, order_amount_kzt=10000, source_type='payment', source_id='limit', idempotency_key='reserve:limit')
            reservation = service.reserve(user_id=user_id, amount=3000, order_amount_kzt=10000, source_type='payment', source_id='limit-ok', idempotency_key='reserve:limit-ok')
            self.assertEqual(reservation.amount, 3000)


if __name__ == '__main__':
    unittest.main()
