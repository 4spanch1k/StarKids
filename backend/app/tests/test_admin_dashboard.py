from datetime import UTC, datetime
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.rate_limit.service import reset_rate_limit_state
from app.core.security.passwords import hash_password
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.auth_throttle_state import AuthThrottleState
from app.db.models.branch import Branch
from app.db.models.loyalty_account import LoyaltyAccount
from app.db.models.loyalty_transaction import LoyaltyTransaction
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_user import MobileUser
from app.db.models.visit import Visit
from app.main import app
from app.modules.admin_dashboard.repository import AdminDashboardRepository
from app.modules.admin_dashboard.schemas import OwnerDashboardPeriod
from app.modules.admin_dashboard.service import AdminDashboardService


class AdminDashboardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            'sqlite://',
            connect_args={'check_same_thread': False},
            poolclass=StaticPool,
        )
        cls.SessionLocal = sessionmaker(
            bind=cls.engine,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
            class_=Session,
        )
        Base.metadata.create_all(cls.engine)

        def override_get_db_session():
            session = cls.SessionLocal()
            try:
                yield session
            finally:
                session.close()

        app.dependency_overrides[get_db_session] = override_get_db_session
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        reset_rate_limit_state()
        with self.SessionLocal() as session:
            for model in (
                LoyaltyTransaction,
                LoyaltyAccount,
                Visit,
                MobilePayment,
                MobileUser,
                AdminSession,
                AuthThrottleState,
                AdminUser,
                Branch,
            ):
                session.query(model).delete()

            session.add(
                Branch(
                    id='branch-main', slug='main', name='Boom Bala Main', city='Almaty',
                    address='Abay 1', short_label='Main', working_hours='10:00-22:00',
                    description='Main branch', phone='+77070000000', whatsapp_phone='+77070000000',
                    map_url=None, route_label=None, parking_hint=None, arrival_hint=None,
                    hero_image_url=None, gallery_image_urls=[], facilities=[], display_order=1,
                    is_active=True,
                )
            )
            password = hash_password('StrongPass123!')
            session.add_all(
                [
                    AdminUser(id='admin-super', email='super@example.com', full_name='Super', password_hash=password, role='super_admin', is_active=True),
                    AdminUser(id='admin-operator', email='operator@example.com', full_name='Operator', password_hash=password, role='operator', is_active=True),
                    AdminUser(id='admin-content', email='content@example.com', full_name='Content', password_hash=password, role='content_manager', is_active=True),
                    AdminUser(id='admin-sales', email='sales@example.com', full_name='Sales', password_hash=password, role='sales_manager', is_active=True),
                ]
            )
            session.add_all(
                [
                    MobileUser(id='user-new', phone='+77071111111', email='new@example.com', is_active=True),
                    MobileUser(id='user-return', phone='+77072222222', email='return@example.com', is_active=True),
                    MobileUser(id='user-old', phone='+77073333333', email='old@example.com', is_active=True),
                ]
            )
            session.commit()

    def test_period_aggregates_use_cash_paid_tickets_visits_and_distinct_families(self) -> None:
        now = datetime(2026, 9, 7, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            current = datetime(2026, 9, 7, 9, tzinfo=UTC)
            session.add_all(
                [
                    self._payment('payment-cash', 'user-new', 2500, 3500, 1000, 1, 'paid', current),
                    self._payment('payment-full-bonus', 'user-return', 0, 3500, 3500, 1, 'paid', current),
                    self._payment('payment-two-tickets', 'user-return', 7000, 7000, 0, 2, 'paid', current),
                    self._payment('payment-failed', 'user-old', 3500, 3500, 0, 1, 'failed', current),
                    self._payment('payment-non-ticket', 'user-old', 9000, 9000, 0, 1, 'paid', current, payable_entity_type='restaurant_order'),
                    self._payment('payment-return-old', 'user-return', 1000, 1000, 0, 1, 'paid', datetime(2026, 8, 20, 9, tzinfo=UTC)),
                    self._payment('payment-old-visit', 'user-old', 1000, 1000, 0, 1, 'paid', datetime(2026, 8, 20, 9, tzinfo=UTC)),
                ]
            )
            session.add_all(
                [
                    self._visit('visit-new', 'payment-cash', 'user-new', current),
                    self._visit('visit-return-old', 'payment-return-old', 'user-return', datetime(2026, 8, 20, 9, tzinfo=UTC)),
                    self._visit('visit-return-1', 'payment-full-bonus', 'user-return', current),
                    self._visit('visit-return-2', 'payment-two-tickets', 'user-return', datetime(2026, 9, 6, 21, tzinfo=UTC)),
                    self._visit('visit-old', 'payment-old-visit', 'user-old', datetime(2026, 8, 20, 9, tzinfo=UTC)),
                ]
            )
            session.add_all(
                [
                    LoyaltyAccount(id='account-new', mobile_user_id='user-new', balance=100, reserved_balance=0, lifetime_earned=100, lifetime_spent=0),
                    LoyaltyAccount(id='account-return', mobile_user_id='user-return', balance=300, reserved_balance=0, lifetime_earned=500, lifetime_spent=200),
                ]
            )
            session.add_all(
                [
                    self._loyalty('earn', 500, 500, 0, 'earn-1', 'posted', current),
                    self._loyalty('reserve', 300, 0, 300, 'reserve-1', 'reserved', current),
                    self._loyalty('release', 300, 0, -300, 'release-1', 'posted', current),
                    self._loyalty('capture', 200, -200, -200, 'capture-1', 'posted', current),
                    self._loyalty('spend', 100, -100, 0, 'spend-1', 'posted', current),
                    self._loyalty('reversal', 50, -50, 0, 'reversal-1', 'posted', current),
                ]
            )
            session.commit()

            result = AdminDashboardService(
                repository=AdminDashboardRepository(session),
                now_provider=lambda: now,
            ).get_owner_dashboard(OwnerDashboardPeriod.TODAY)

        self.assertEqual(result.ticketCashCollectedTenge, 9500)
        self.assertEqual(result.paidTicketPurchases, 3)
        self.assertEqual(result.ticketsSold, 4)
        self.assertEqual(result.visits, 3)
        self.assertEqual(result.newFamilies, 1)
        self.assertEqual(result.returningFamilies, 1)
        self.assertEqual(result.bonusesIssued, 500)
        self.assertEqual(result.bonusesRedeemed, 300)
        self.assertEqual(result.outstandingBonusBalance, 400)

    def test_today_uses_almaty_midnight_boundary(self) -> None:
        now = datetime(2026, 9, 7, 20, tzinfo=UTC)  # Sep 8, 01:00 in Almaty.
        with self.SessionLocal() as session:
            session.add_all(
                [
                    self._payment('boundary-in', 'user-new', 1000, 1000, 0, 1, 'paid', datetime(2026, 9, 7, 19, 30, tzinfo=UTC)),
                    self._payment('boundary-out', 'user-return', 2000, 2000, 0, 1, 'paid', datetime(2026, 9, 7, 18, 59, tzinfo=UTC)),
                ]
            )
            session.commit()
            result = AdminDashboardService(
                repository=AdminDashboardRepository(session), now_provider=lambda: now,
            ).get_owner_dashboard(OwnerDashboardPeriod.TODAY)

        self.assertEqual(result.ticketCashCollectedTenge, 1000)
        self.assertEqual(result.paidTicketPurchases, 1)
        self.assertEqual(result.periodStart.isoformat(), '2026-09-08T00:00:00+05:00')

    def test_empty_dashboard_returns_truthful_zeros(self) -> None:
        with self.SessionLocal() as session:
            result = AdminDashboardService(
                repository=AdminDashboardRepository(session),
                now_provider=lambda: datetime(2026, 9, 7, 12, tzinfo=UTC),
            ).get_owner_dashboard(OwnerDashboardPeriod.THIRTY_DAYS)
        self.assertEqual(result.ticketCashCollectedTenge, 0)
        self.assertEqual(result.paidTicketPurchases, 0)
        self.assertEqual(result.ticketsSold, 0)
        self.assertEqual(result.visits, 0)
        self.assertEqual(result.outstandingBonusBalance, 0)

    def test_seven_and_thirty_day_periods_use_calendar_midnights(self) -> None:
        now = datetime(2026, 9, 7, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            session.add_all(
                [
                    self._payment('seven-in', 'user-new', 100, 100, 0, 1, 'paid', datetime(2026, 9, 1, 0, tzinfo=UTC)),
                    self._payment('seven-out', 'user-return', 200, 200, 0, 1, 'paid', datetime(2026, 8, 31, 18, 59, tzinfo=UTC)),
                    self._payment('thirty-in', 'user-old', 300, 300, 0, 1, 'paid', datetime(2026, 8, 8, 19, tzinfo=UTC)),
                    self._payment('thirty-out', 'user-new', 400, 400, 0, 1, 'paid', datetime(2026, 8, 8, 18, 59, tzinfo=UTC)),
                ]
            )
            session.commit()
            service = AdminDashboardService(
                repository=AdminDashboardRepository(session), now_provider=lambda: now,
            )
            seven = service.get_owner_dashboard(OwnerDashboardPeriod.SEVEN_DAYS)
            thirty = service.get_owner_dashboard(OwnerDashboardPeriod.THIRTY_DAYS)

        self.assertEqual(seven.ticketCashCollectedTenge, 100)
        self.assertEqual(seven.paidTicketPurchases, 1)
        self.assertEqual(thirty.ticketCashCollectedTenge, 600)
        self.assertEqual(thirty.paidTicketPurchases, 3)

    def test_dashboard_is_super_admin_only(self) -> None:
        self.assertEqual(self.client.get('/api/v1/admin/dashboard/owner').status_code, 401)
        self.assertEqual(
            self.client.get('/api/v1/admin/dashboard/owner', headers=self._auth_headers('super@example.com')).status_code,
            200,
        )
        for email in ('operator@example.com', 'content@example.com', 'sales@example.com'):
            self.assertEqual(
                self.client.get('/api/v1/admin/dashboard/owner', headers=self._auth_headers(email)).status_code,
                403,
            )

    def _auth_headers(self, email: str) -> dict[str, str]:
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={'email': email, 'password': 'StrongPass123!'},
        )
        self.assertEqual(response.status_code, 200)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}

    @staticmethod
    def _payment(
        payment_id: str,
        user_id: str,
        cash: int,
        gross: int,
        bonus: int,
        quantity: int,
        status: str,
        paid_at: datetime,
        *,
        payable_entity_type: str = 'branch_ticket_order',
    ) -> MobilePayment:
        return MobilePayment(
            id=payment_id,
            mobile_user_id=user_id,
            branch_id='branch-main',
            payable_entity_type=payable_entity_type,
            payable_entity_id=f'order-{payment_id}',
            local_order_id=f'BB-{payment_id}',
            idempotency_key=f'key-{payment_id}',
            amount_tenge=cash,
            gross_amount_tenge=gross,
            bonus_amount=bonus,
            cash_amount_tenge=cash,
            currency='KZT',
            quantity=quantity,
            visit_date=paid_at.date(),
            ticket_items=[],
            status=status,
            init_payload={},
            callback_payload={},
            paid_at=paid_at if status == 'paid' else None,
        )

    @staticmethod
    def _visit(visit_id: str, payment_id: str, user_id: str, started_at: datetime) -> Visit:
        return Visit(
            id=visit_id,
            mobile_payment_id=payment_id,
            mobile_user_id=user_id,
            branch_id='branch-main',
            status='completed',
            started_at=started_at,
        )

    @staticmethod
    def _loyalty(
        transaction_type: str,
        amount: int,
        balance_delta: int,
        reserved_delta: int,
        suffix: str,
        status: str,
        created_at: datetime,
    ) -> LoyaltyTransaction:
        return LoyaltyTransaction(
            id=f'transaction-{suffix}',
            mobile_user_id='user-new',
            account_id='account-new',
            type=transaction_type,
            amount=amount,
            balance_delta=balance_delta,
            reserved_delta=reserved_delta,
            source_type='test',
            source_id=suffix,
            idempotency_key=f'idempotency-{suffix}',
            status=status,
            metadata_json={},
            created_at=created_at,
        )


if __name__ == '__main__':
    unittest.main()
