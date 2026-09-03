from datetime import timedelta
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config.settings import get_settings
from app.core.database.session import get_db_session
from app.core.time.business_time import business_today
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.auth_throttle_state import AuthThrottleState
from app.db.models.branch import Branch
from app.db.models.issued_ticket import IssuedTicket
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.models.ticket_redemption import TicketRedemption
from app.db.repositories.ticket_redemption_repository import TicketRedemptionRepository
from app.main import app
from app.modules.mobile_payments.ticket_qr_service import TicketQrService
from app.core.security.passwords import hash_password


class TicketRedemptionEndpointTests(unittest.TestCase):
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
        settings = get_settings()
        cls._original_qr_secret = settings.ticket_qr_secret
        settings.ticket_qr_secret = 'r' * 48

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
        get_settings().ticket_qr_secret = cls._original_qr_secret
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(TicketRedemption).delete()
            session.query(IssuedTicket).delete()
            session.query(MobilePayment).delete()
            session.query(AdminSession).delete()
            session.query(AuthThrottleState).delete()
            session.query(MobileSession).delete()
            session.query(AdminUser).delete()
            session.query(MobileUser).delete()
            session.query(Branch).delete()
            session.add(
                Branch(
                    id='branch-main', slug='main', name='Boom Bala Main', city='Shymkent',
                    address='Al-Farabi', short_label='Main', working_hours='11:00 - 23:00',
                    description='Main', phone='+77070000000', whatsapp_phone='+77070000000',
                    gallery_image_urls=[], facilities=[], display_order=1, is_active=True,
                )
            )
            session.add(MobileUser(id='mobile-1', phone='+77070000001', is_active=True))
            for role, email in (
                ('super_admin', 'super@example.com'),
                ('operator', 'operator@example.com'),
                ('content_manager', 'content@example.com'),
                ('sales_manager', 'sales@example.com'),
            ):
                session.add(
                    AdminUser(
                        id=f'admin-{role}', email=email, full_name=role,
                        password_hash=hash_password('StrongPass123!'), role=role, is_active=True,
                    )
                )
            session.add(
                MobilePayment(
                    id='payment-1', mobile_user_id='mobile-1', branch_id='branch-main',
                    payable_entity_type='branch_ticket_order', payable_entity_id='branch-main',
                    local_order_id='sk-redemption-1', idempotency_key='redemption-key-1',
                    amount_tenge=2700, currency='KZT', quantity=1,
                    visit_date=business_today(), ticket_items=[{
                        'ticketItemId': 'ticket-child', 'title': 'Детский билет',
                        'priceTenge': 2700, 'quantity': 1,
                    }], status='paid', init_payload={}, callback_payload={},
                )
            )
            session.add(
                IssuedTicket(
                    id='ticket-1', mobile_payment_id='payment-1', ticket_number='BB-0000000001',
                    ticket_item_id='ticket-child', title_snapshot='Детский билет',
                    price_tenge=2700, branch_id='branch-main', visit_date=business_today(),
                    line_index=0, status='issued',
                )
            )
            session.commit()

    def _admin_headers(self, role: str = 'operator') -> dict[str, str]:
        email = {
            'super_admin': 'super@example.com', 'operator': 'operator@example.com',
            'content_manager': 'content@example.com', 'sales_manager': 'sales@example.com',
        }[role]
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={'email': email, 'password': 'StrongPass123!'},
        )
        self.assertEqual(response.status_code, 200)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}

    def _qr(self, ticket_id: str = 'ticket-1') -> str:
        return TicketQrService(get_settings().ticket_qr_secret).build_payload(ticket_id)

    def _redeem(self, *, role: str = 'operator', qr: str | None = None, branch_id: str = 'branch-main'):
        return self.client.post(
            '/api/v1/admin/tickets/redeem',
            headers=self._admin_headers(role),
            json={'qrPayload': qr or self._qr(), 'branchId': branch_id},
        )

    def test_valid_qr_redeems_once_and_records_audit(self) -> None:
        response = self._redeem()
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['outcome'], 'redeemed')
        self.assertEqual(body['status'], 'used')
        with self.SessionLocal() as session:
            ticket = session.get(IssuedTicket, 'ticket-1')
            redemption = session.scalar(select(TicketRedemption))
            self.assertEqual(ticket.status, 'used')
            self.assertEqual(redemption.redeemed_by_admin_user_id, 'admin-operator')
            self.assertEqual(redemption.branch_id, 'branch-main')

    def test_second_scan_is_already_used_without_changing_original_audit(self) -> None:
        first = self._redeem()
        second = self._redeem()
        self.assertEqual(first.json()['outcome'], 'redeemed')
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.json()['outcome'], 'already_used')
        self.assertEqual(second.json()['redeemedAt'], first.json()['redeemedAt'])
        with self.SessionLocal() as session:
            self.assertEqual(session.query(TicketRedemption).count(), 1)

    def test_invalid_qr_and_nonexistent_ticket_are_rejected_without_side_effects(self) -> None:
        invalid = self._redeem(qr='bb_ticket:v1:ticket-1:invalid')
        nonexistent = self._redeem(qr=self._qr('missing-ticket'))
        self.assertEqual(invalid.status_code, 400)
        self.assertEqual(invalid.json()['error']['code'], 'invalid_qr')
        self.assertEqual(nonexistent.status_code, 404)
        self.assertEqual(nonexistent.json()['error']['code'], 'ticket_not_found')
        with self.SessionLocal() as session:
            self.assertEqual(session.query(TicketRedemption).count(), 0)
            self.assertEqual(session.get(IssuedTicket, 'ticket-1').status, 'issued')

    def test_wrong_branch_and_wrong_date_leave_ticket_issued(self) -> None:
        wrong_branch = self._redeem(branch_id='branch-other')
        self.assertEqual(wrong_branch.status_code, 409)
        self.assertEqual(wrong_branch.json()['error']['code'], 'wrong_branch')
        with self.SessionLocal() as session:
            session.get(IssuedTicket, 'ticket-1').visit_date = business_today() + timedelta(days=1)
            session.commit()
        wrong_date = self._redeem()
        self.assertEqual(wrong_date.status_code, 409)
        self.assertEqual(wrong_date.json()['error']['code'], 'wrong_date')
        with self.SessionLocal() as session:
            self.assertEqual(session.query(TicketRedemption).count(), 0)
            self.assertEqual(session.get(IssuedTicket, 'ticket-1').status, 'issued')

    def test_missing_visit_date_is_invalid_ticket_data(self) -> None:
        with self.SessionLocal() as session:
            session.get(IssuedTicket, 'ticket-1').visit_date = None
            session.commit()
        response = self._redeem()
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()['error']['code'], 'invalid_ticket_data')
        with self.SessionLocal() as session:
            self.assertEqual(session.query(TicketRedemption).count(), 0)
            self.assertEqual(session.get(IssuedTicket, 'ticket-1').status, 'issued')

    def test_non_issued_status_is_rejected(self) -> None:
        with self.SessionLocal() as session:
            session.get(IssuedTicket, 'ticket-1').status = 'pending'
            session.commit()
        response = self._redeem()
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()['error']['code'], 'invalid_status')

    def test_only_operator_and_super_admin_can_redeem(self) -> None:
        self.assertEqual(self._redeem(role='super_admin').json()['outcome'], 'redeemed')
        self.setUp()
        self.assertEqual(self._redeem(role='content_manager').status_code, 403)
        self.setUp()
        self.assertEqual(self._redeem(role='sales_manager').status_code, 403)

    def test_database_unique_constraint_allows_one_redemption(self) -> None:
        with self.SessionLocal() as session:
            session.add_all([
                TicketRedemption(
                    id='redemption-1', issued_ticket_id='ticket-1', branch_id='branch-main',
                    redeemed_by_admin_user_id='admin-operator',
                ),
                TicketRedemption(
                    id='redemption-2', issued_ticket_id='ticket-1', branch_id='branch-main',
                    redeemed_by_admin_user_id='admin-super_admin',
                ),
            ])
            with self.assertRaises(IntegrityError):
                session.commit()
            session.rollback()

    def test_mobile_qr_is_unavailable_after_redemption(self) -> None:
        self._redeem()
        response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={'email': 'parent@example.com', 'password': 'StrongPass123!'},
        )
        self.assertEqual(response.status_code, 200)
        headers = {'Authorization': f"Bearer {response.json()['access_token']}"}
        response = self.client.get('/api/v1/mobile/tickets/ticket-1/qr', headers=headers)
        self.assertEqual(response.status_code, 404)


if __name__ == '__main__':
    unittest.main()
