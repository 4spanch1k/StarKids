from datetime import UTC, datetime, timedelta
from decimal import Decimal
import unittest

from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.models import Base
from app.db.models.loyalty_rule import LoyaltyRule
from app.db.models.loyalty_transaction import LoyaltyTransaction
from app.db.models.loyalty_settings import LoyaltySettings
from app.db.models.loyalty_account import LoyaltyAccount
from app.core.exceptions.http import DomainHTTPException
from app.db.models.mobile_user import MobileUser
from app.modules.loyalty.service import LoyaltyService, ensure_rule_does_not_overlap
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
            session.query(LoyaltyAccount).delete()
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

    def test_bonus_value_is_immutable_one_kzt(self) -> None:
        with self.SessionLocal() as session:
            service = LoyaltyService(LoyaltyRepository(session))
            settings = service.update_settings(max_redemption_percent=Decimal('30'))
            self.assertEqual(settings.bonus_value_kzt, Decimal('1.0000'))
            session.commit()
        with self.SessionLocal() as session:
            settings = session.get(LoyaltySettings, 1)
            self.assertIsNotNone(settings)
            settings.bonus_value_kzt = Decimal('2')
            with self.assertRaises(IntegrityError):
                session.flush()
            session.rollback()

    def test_overlapping_active_rules_are_rejected_but_touching_periods_are_allowed(self) -> None:
        with self.SessionLocal() as session:
            first = LoyaltyRule(event_type='ticket_purchase', reward_type='percent', value=Decimal('5'), is_active=True, starts_at=datetime(2026, 9, 1, tzinfo=UTC), ends_at=datetime(2026, 9, 10, tzinfo=UTC))
            session.add(first)
            session.commit()
            with self.assertRaises(DomainHTTPException) as context:
                ensure_rule_does_not_overlap(LoyaltyRepository(session), event_type='ticket_purchase', starts_at=datetime(2026, 9, 5, tzinfo=UTC), ends_at=datetime(2026, 9, 20, tzinfo=UTC))
            self.assertEqual(context.exception.code, 'loyalty_rule_overlap')
            ensure_rule_does_not_overlap(LoyaltyRepository(session), event_type='ticket_purchase', starts_at=datetime(2026, 9, 10, tzinfo=UTC), ends_at=datetime(2026, 9, 20, tzinfo=UTC))
            session.add(LoyaltyRule(event_type='birthday_purchase', reward_type='percent', value=Decimal('5'), is_active=True))
            session.commit()
            with self.assertRaises(DomainHTTPException):
                ensure_rule_does_not_overlap(LoyaltyRepository(session), event_type='birthday_purchase', starts_at=datetime(2026, 9, 15, tzinfo=UTC), ends_at=datetime(2026, 9, 20, tzinfo=UTC))

    def test_ambiguous_rule_resolution_fails_closed(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add_all([
                LoyaltyRule(event_type='ticket_purchase', reward_type='percent', value=Decimal('5'), is_active=True),
                LoyaltyRule(event_type='ticket_purchase', reward_type='percent', value=Decimal('10'), is_active=True),
            ])
            session.commit()
            with self.assertRaises(DomainHTTPException) as context:
                LoyaltyService(LoyaltyRepository(session)).apply_event(user_id=user_id, event_type='ticket_purchase', source_type='payment', source_id='ambiguous', cash_amount_kzt=10000, idempotency_key='ambiguous')
            self.assertEqual(context.exception.code, 'loyalty_ambiguous_rule')

    def test_terminal_reservation_transitions_are_safe(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add(LoyaltyRule(event_type='registration', reward_type='fixed', value=Decimal('5000'), is_active=True))
            session.commit()
            service = LoyaltyService(LoyaltyRepository(session))
            service.apply_event(user_id=user_id, event_type='registration', source_type='user', source_id=user_id, cash_amount_kzt=None, idempotency_key=f'registration:{user_id}')
            reservation = service.reserve(user_id=user_id, amount=3000, source_type='payment', source_id='state-machine', idempotency_key='reserve:state-machine')
            captured = service.capture(user_id=user_id, reservation_id=reservation.id, idempotency_key='capture:state-machine')
            self.assertEqual(captured.amount, 3000)
            self.assertEqual(service.capture(user_id=user_id, reservation_id=reservation.id, idempotency_key='capture:state-machine').id, captured.id)
            with self.assertRaises(DomainHTTPException):
                service.capture(user_id=user_id, reservation_id=reservation.id, idempotency_key='capture:state-machine:retry')
            with self.assertRaises(DomainHTTPException):
                service.release(user_id=user_id, reservation_id=reservation.id, idempotency_key='release:state-machine')
            self.assertEqual(service.account_response(user_id), {'balance': 2000, 'reservedBalance': 0, 'availableBalance': 2000, 'lifetimeEarned': 5000, 'lifetimeSpent': 3000})

    def test_release_then_capture_is_forbidden_and_release_is_not_a_balance_credit(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add(LoyaltyRule(event_type='registration', reward_type='fixed', value=Decimal('5000'), is_active=True))
            session.commit()
            service = LoyaltyService(LoyaltyRepository(session))
            service.apply_event(user_id=user_id, event_type='registration', source_type='user', source_id=user_id, cash_amount_kzt=None, idempotency_key=f'registration:{user_id}')
            reservation = service.reserve(user_id=user_id, amount=3000, source_type='payment', source_id='release-state-machine', idempotency_key='reserve:release-state-machine')
            released = service.release(user_id=user_id, reservation_id=reservation.id, idempotency_key='release:release-state-machine')
            self.assertEqual(released.amount, 3000)
            self.assertEqual(service.release(user_id=user_id, reservation_id=reservation.id, idempotency_key='release:release-state-machine').id, released.id)
            with self.assertRaises(DomainHTTPException):
                service.capture(user_id=user_id, reservation_id=reservation.id, idempotency_key='capture:release-state-machine')
            self.assertEqual(service.account_response(user_id)['balance'], 5000)

    def test_reservation_requires_available_balance(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add(LoyaltyRule(event_type='registration', reward_type='fixed', value=Decimal('5000'), is_active=True))
            session.commit()
            service = LoyaltyService(LoyaltyRepository(session))
            service.apply_event(user_id=user_id, event_type='registration', source_type='user', source_id=user_id, cash_amount_kzt=None, idempotency_key=f'registration:{user_id}')
            service.reserve(user_id=user_id, amount=2000, source_type='payment', source_id='available', idempotency_key='reserve:available')
            with self.assertRaises(DomainHTTPException):
                service.reserve(user_id=user_id, amount=4000, source_type='payment', source_id='too-much', idempotency_key='reserve:too-much')

    def test_capture_and_release_without_reservation_are_rejected(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            service = LoyaltyService(LoyaltyRepository(session))
            with self.assertRaises(DomainHTTPException):
                service.capture(user_id=user_id, reservation_id='missing-reservation', idempotency_key='capture:missing')
            with self.assertRaises(DomainHTTPException):
                service.release(user_id=user_id, reservation_id='missing-reservation', idempotency_key='release:missing')

    def test_reversal_is_idempotent_and_rejects_spent_balance(self) -> None:
        user_id = self._user()
        with self.SessionLocal() as session:
            session.add(LoyaltyRule(event_type='registration', reward_type='fixed', value=Decimal('500'), is_active=True))
            session.commit()
            service = LoyaltyService(LoyaltyRepository(session))
            earned = service.apply_event(user_id=user_id, event_type='registration', source_type='user', source_id=user_id, cash_amount_kzt=None, idempotency_key=f'registration:{user_id}')
            reversal = service.reverse(user_id=user_id, original_transaction_id=earned.id, idempotency_key='reverse:first')
            self.assertEqual(service.reverse(user_id=user_id, original_transaction_id=earned.id, idempotency_key='reverse:retry').id, reversal.id)
            earned_again = service.apply_event(user_id=user_id, event_type='registration', source_type='user', source_id='spent-reversal', cash_amount_kzt=None, idempotency_key='registration:spent-reversal')
            service.spend(user_id=user_id, amount=500, source_type='payment', source_id='spent-reversal', idempotency_key='spend:spent-reversal')
            with self.assertRaises(DomainHTTPException):
                service.reverse(user_id=user_id, original_transaction_id=earned_again.id, idempotency_key='reverse:spent')

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
