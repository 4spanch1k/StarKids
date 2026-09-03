from datetime import timedelta
import unittest
from unittest.mock import patch

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
from app.db.models.visit import Visit
from app.db.repositories.ticket_redemption_repository import TicketRedemptionRepository
from app.db.repositories.branch_repository import BranchRepository
from app.db.repositories.issued_ticket_repository import IssuedTicketRepository
from app.db.repositories.mobile_payment_repository import MobilePaymentRepository
from app.db.repositories.visit_repository import VisitRepository
from app.main import app
from app.modules.admin_tickets.service import TicketRedemptionService
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
            session.query(Visit).delete()
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
                    address='Al-Farabi', short_label='Main', working_hours='00:00 - 23:59',
                    description='Main', phone='+77070000000', whatsapp_phone='+77070000000',
                    gallery_image_urls=[], facilities=[], display_order=1, is_active=True,
                )
            )
            session.add(MobileUser(
                id='mobile-1', phone='+77070000001', email='parent@example.com',
                password_hash=hash_password('StrongPass123!'), is_active=True,
            ))
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
            self.assertIsNotNone(redemption.visit_id)
            self.assertEqual(body['visitId'], redemption.visit_id)
            self.assertEqual(session.query(Visit).count(), 1)

    def test_second_scan_is_already_used_without_changing_original_audit(self) -> None:
        first = self._redeem()
        second = self._redeem()
        self.assertEqual(first.json()['outcome'], 'redeemed')
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.json()['outcome'], 'already_used')
        self.assertEqual(second.json()['redeemedAt'], first.json()['redeemedAt'])
        with self.SessionLocal() as session:
            self.assertEqual(session.query(TicketRedemption).count(), 1)
            self.assertEqual(session.query(Visit).count(), 1)

    def test_multiple_admissions_in_one_order_share_one_visit(self) -> None:
        with self.SessionLocal() as session:
            session.add(IssuedTicket(
                id='ticket-2', mobile_payment_id='payment-1', ticket_number='BB-0000000002',
                ticket_item_id='ticket-child', title_snapshot='Взрослый билет',
                price_tenge=0, branch_id='branch-main', visit_date=business_today(),
                line_index=1, status='issued',
            ))
            session.commit()
        first = self._redeem(qr=self._qr('ticket-1'))
        second = self._redeem(qr=self._qr('ticket-2'))
        self.assertEqual(first.json()['outcome'], 'redeemed')
        self.assertEqual(second.json()['outcome'], 'redeemed')
        self.assertEqual(first.json()['visitId'], second.json()['visitId'])
        with self.SessionLocal() as session:
            self.assertEqual(session.query(Visit).count(), 1)

    def test_current_visit_is_exposed_only_after_successful_redemption(self) -> None:
        register = self.client.post(
            '/api/v1/mobile/auth/login',
            json={'email': 'parent@example.com', 'password': 'StrongPass123!'},
        )
        self.assertEqual(register.status_code, 200)
        headers = {'Authorization': f"Bearer {register.json()['access_token']}"}
        before = self.client.get('/api/v1/mobile/visits/current', headers=headers)
        self.assertEqual(before.status_code, 200)
        self.assertIsNone(before.json())
        self._redeem()
        after = self.client.get('/api/v1/mobile/visits/current', headers=headers)
        self.assertEqual(after.status_code, 200)
        self.assertEqual(after.json()['status'], 'active')

    def test_staff_lookup_finds_paid_order_by_order_number_or_phone(self) -> None:
        response = self.client.get(
            '/api/v1/admin/tickets/lookup',
            params={'query': 'sk-redemption-1'},
            headers=self._admin_headers(),
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['items'][0]['localOrderId'], 'sk-redemption-1')
        self.assertEqual(response.json()['items'][0]['tickets'][0]['status'], 'issued')
        response = self.client.get(
            '/api/v1/admin/tickets/lookup',
            params={'query': '+77070000001'},
            headers=self._admin_headers(),
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()['items']), 1)

    def test_manual_redeem_uses_shared_visit_and_records_reason(self) -> None:
        response = self.client.post(
            '/api/v1/admin/tickets/redeem-manual',
            headers=self._admin_headers(),
            json={
                'ticketId': 'ticket-1',
                'branchId': 'branch-main',
                'reason': 'qr_unavailable',
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['outcome'], 'redeemed')
        with self.SessionLocal() as session:
            redemption = session.scalar(select(TicketRedemption))
            self.assertEqual(redemption.source, 'manual')
            self.assertEqual(redemption.reason, 'qr_unavailable')
            self.assertEqual(session.query(Visit).count(), 1)

        second = self.client.post(
            '/api/v1/admin/tickets/redeem-manual',
            headers=self._admin_headers(),
            json={'ticketId': 'ticket-1', 'branchId': 'branch-main', 'reason': 'support_override'},
        )
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.json()['outcome'], 'already_used')

    def test_manual_redeem_is_staff_only(self) -> None:
        response = self.client.post(
            '/api/v1/admin/tickets/redeem-manual',
            headers=self._admin_headers('content_manager'),
            json={'ticketId': 'ticket-1', 'branchId': 'branch-main', 'reason': 'qr_unavailable'},
        )
        self.assertEqual(response.status_code, 403)

    def test_current_visit_lazily_completes_after_branch_closing(self) -> None:
        from datetime import datetime
        from app.core.time.business_time import BUSINESS_TIMEZONE

        old_date = business_today() - timedelta(days=1)
        with self.SessionLocal() as session:
            payment = session.get(MobilePayment, 'payment-1')
            payment.visit_date = old_date
            session.add(Visit(
                id='visit-stale', mobile_payment_id='payment-1', mobile_user_id='mobile-1',
                branch_id='branch-main', status='active',
                started_at=datetime.combine(old_date, datetime.min.time(), tzinfo=BUSINESS_TIMEZONE),
            ))
            session.commit()
        login = self.client.post(
            '/api/v1/mobile/auth/login',
            json={'email': 'parent@example.com', 'password': 'StrongPass123!'},
        )
        response = self.client.get(
            '/api/v1/mobile/visits/current',
            headers={'Authorization': f"Bearer {login.json()['access_token']}"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.json())
        with self.SessionLocal() as session:
            stale = session.get(Visit, 'visit-stale')
            self.assertEqual(stale.status, 'completed')
            self.assertEqual(stale.completion_reason, 'validity_cutoff')
            self.assertIsNotNone(stale.ended_at)

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

    def test_unpaid_order_cannot_be_redeemed(self) -> None:
        with self.SessionLocal() as session:
            session.get(MobilePayment, 'payment-1').status = 'pending'
            session.commit()
        response = self._redeem()
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()['error']['code'], 'invalid_payment')

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

    def test_redemption_transaction_failure_rolls_back_visit_and_ticket(self) -> None:
        with self.SessionLocal() as session:
            service = TicketRedemptionService(
                issued_ticket_repository=IssuedTicketRepository(session),
                redemption_repository=TicketRedemptionRepository(session),
                payment_repository=MobilePaymentRepository(session),
                visit_repository=VisitRepository(session),
                branch_repository=BranchRepository(session),
                ticket_qr_service=TicketQrService(get_settings().ticket_qr_secret),
            )
            admin = session.get(AdminUser, 'admin-operator')
            with patch.object(session, 'commit', side_effect=RuntimeError('commit failed')):
                with self.assertRaises(RuntimeError):
                    service.redeem(
                        qr_payload=self._qr(),
                        branch_id='branch-main',
                        admin_user=admin,
                    )
            session.rollback()

        with self.SessionLocal() as session:
            self.assertEqual(session.query(Visit).count(), 0)
            self.assertEqual(session.query(TicketRedemption).count(), 0)
            self.assertEqual(session.get(IssuedTicket, 'ticket-1').status, 'issued')

    def test_mobile_qr_is_unavailable_after_redemption(self) -> None:
        self._redeem()
        response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={'email': 'qr-parent@example.com', 'password': 'StrongPass123!'},
        )
        self.assertEqual(response.status_code, 200)
        headers = {'Authorization': f"Bearer {response.json()['access_token']}"}
        response = self.client.get('/api/v1/mobile/tickets/ticket-1/qr', headers=headers)
        self.assertEqual(response.status_code, 404)


if __name__ == '__main__':
    unittest.main()
