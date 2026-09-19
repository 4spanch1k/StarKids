import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config.settings import get_settings
from app.core.database.session import get_db_session
from app.core.rate_limit.service import reset_rate_limit_state
from app.core.security.passwords import hash_password
from app.core.time.business_time import business_today
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.auth_throttle_state import AuthThrottleState
from app.db.models.branch import Branch
from app.db.models.issued_ticket import IssuedTicket
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_user import MobileUser
from app.db.models.ticket_redemption import TicketRedemption
from app.db.models.visit import Visit
from app.main import app
from app.modules.mobile_payments.ticket_qr_service import TicketQrService


class StaffBranchScopeTests(unittest.TestCase):
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
        cls.secret = 's' * 48
        settings = get_settings()
        cls._original_qr_secret = settings.ticket_qr_secret
        settings.ticket_qr_secret = cls.secret

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
        reset_rate_limit_state()
        with self.SessionLocal() as session:
            for model in (
                TicketRedemption,
                Visit,
                IssuedTicket,
                MobilePayment,
                AdminSession,
                AuthThrottleState,
                AdminUser,
                MobileUser,
                Branch,
            ):
                session.query(model).delete()

            branch_a = self._branch('branch-a', 'A', active=True)
            branch_b = self._branch('branch-b', 'B', active=True)
            mobile_user = MobileUser(
                id='mobile-user',
                phone='+77070000001',
                email='parent@example.com',
                password_hash=hash_password('StrongPass123!'),
                is_active=True,
            )
            super_admin = self._admin('admin-super', 'super@example.com', 'super_admin')
            operator = self._admin(
                'admin-operator',
                'operator@example.com',
                'operator',
                branch_id=branch_a.id,
            )
            payment_a = self._payment('payment-a', branch_a.id, 'order-a', mobile_user.id)
            payment_b = self._payment('payment-b', branch_b.id, 'order-b', mobile_user.id)
            ticket_a = self._ticket('ticket-a', payment_a.id, branch_a.id, 'A-1')
            ticket_b = self._ticket('ticket-b', payment_b.id, branch_b.id, 'B-1')
            session.add_all(
                [
                    branch_a,
                    branch_b,
                    mobile_user,
                    super_admin,
                    operator,
                    payment_a,
                    payment_b,
                    ticket_a,
                    ticket_b,
                ]
            )
            session.commit()

    def _branch(self, branch_id: str, label: str, *, active: bool) -> Branch:
        return Branch(
            id=branch_id,
            slug=branch_id,
            name=f'Boom Bala {label}',
            city='Almaty',
            address='Test',
            short_label=label,
            working_hours='10:00-22:00',
            description='Test',
            phone='+77070000000',
            whatsapp_phone='+77070000000',
            gallery_image_urls=[],
            facilities=[],
            is_active=active,
        )

    def _admin(self, admin_id: str, email: str, role: str, *, branch_id: str | None = None) -> AdminUser:
        return AdminUser(
            id=admin_id,
            email=email,
            full_name=role,
            password_hash=hash_password('StrongPass123!'),
            role=role,
            branch_id=branch_id,
            is_active=True,
        )

    def _payment(self, payment_id: str, branch_id: str, order_id: str, user_id: str) -> MobilePayment:
        return MobilePayment(
            id=payment_id,
            mobile_user_id=user_id,
            branch_id=branch_id,
            payable_entity_type='branch_ticket_order',
            payable_entity_id=order_id,
            local_order_id=order_id,
            idempotency_key=f'{payment_id}-key',
            amount_tenge=2700,
            currency='KZT',
            quantity=1,
            visit_date=business_today(),
            ticket_items=[],
            status='paid',
            init_payload={},
            callback_payload={},
        )

    def _ticket(self, ticket_id: str, payment_id: str, branch_id: str, number: str) -> IssuedTicket:
        return IssuedTicket(
            id=ticket_id,
            mobile_payment_id=payment_id,
            ticket_number=number,
            ticket_item_id='item',
            title_snapshot='Admission',
            price_tenge=2700,
            branch_id=branch_id,
            visit_date=business_today(),
            line_index=0,
            status='issued',
        )

    def _headers(self, email: str) -> dict[str, str]:
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={'email': email, 'password': 'StrongPass123!'},
        )
        self.assertEqual(response.status_code, 200)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}

    def _qr(self, ticket_id: str) -> str:
        return TicketQrService(self.secret).build_payload(ticket_id)

    def test_operator_can_redeem_ticket_in_assigned_branch(self) -> None:
        response = self.client.post(
            '/api/v1/admin/tickets/redeem',
            headers=self._headers('operator@example.com'),
            json={'qrPayload': self._qr('ticket-a'), 'branchId': 'branch-a'},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['outcome'], 'redeemed')

    def test_operator_foreign_qr_is_denied_without_side_effect(self) -> None:
        response = self.client.post(
            '/api/v1/admin/tickets/redeem',
            headers=self._headers('operator@example.com'),
            json={'qrPayload': self._qr('ticket-b'), 'branchId': 'branch-b'},
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error']['code'], 'branch_access_denied')
        with self.SessionLocal() as session:
            self.assertEqual(session.get(IssuedTicket, 'ticket-b').status, 'issued')
            self.assertEqual(session.query(TicketRedemption).count(), 0)
            self.assertEqual(session.query(Visit).count(), 0)

    def test_operator_manual_foreign_branch_is_denied_without_side_effect(self) -> None:
        response = self.client.post(
            '/api/v1/admin/tickets/redeem-manual',
            headers=self._headers('operator@example.com'),
            json={'ticketId': 'ticket-b', 'branchId': 'branch-b', 'reason': 'qr_unavailable'},
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error']['code'], 'branch_access_denied')
        with self.SessionLocal() as session:
            self.assertEqual(session.get(IssuedTicket, 'ticket-b').status, 'issued')
            self.assertEqual(session.query(TicketRedemption).count(), 0)

    def test_operator_cannot_probe_already_used_foreign_ticket(self) -> None:
        redeemed = self.client.post(
            '/api/v1/admin/tickets/redeem',
            headers=self._headers('super@example.com'),
            json={'qrPayload': self._qr('ticket-b'), 'branchId': 'branch-b'},
        )
        self.assertEqual(redeemed.status_code, 200)

        response = self.client.post(
            '/api/v1/admin/tickets/redeem',
            headers=self._headers('operator@example.com'),
            json={'qrPayload': self._qr('ticket-b'), 'branchId': 'branch-a'},
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error']['code'], 'branch_access_denied')

    def test_branchless_operator_and_inactive_assignment_fail_closed(self) -> None:
        with self.SessionLocal() as session:
            session.get(AdminUser, 'admin-operator').branch_id = None
            session.commit()
        response = self.client.post(
            '/api/v1/admin/tickets/redeem',
            headers=self._headers('operator@example.com'),
            json={'qrPayload': self._qr('ticket-a'), 'branchId': 'branch-a'},
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error']['code'], 'branch_not_assigned')
        lookup = self.client.get(
            '/api/v1/admin/tickets/lookup',
            headers=self._headers('operator@example.com'),
            params={'query': '+77070000001'},
        )
        self.assertEqual(lookup.status_code, 403)
        self.assertEqual(lookup.json()['error']['code'], 'branch_not_assigned')

        with self.SessionLocal() as session:
            operator = session.get(AdminUser, 'admin-operator')
            operator.branch_id = 'branch-a'
            session.get(Branch, 'branch-a').is_active = False
            session.commit()
        response = self.client.post(
            '/api/v1/admin/tickets/redeem-manual',
            headers=self._headers('operator@example.com'),
            json={'ticketId': 'ticket-a', 'branchId': 'branch-a', 'reason': 'qr_unavailable'},
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error']['code'], 'branch_inactive')

    def test_super_admin_keeps_global_branch_access(self) -> None:
        response = self.client.post(
            '/api/v1/admin/tickets/redeem',
            headers=self._headers('super@example.com'),
            json={'qrPayload': self._qr('ticket-b'), 'branchId': 'branch-b'},
        )
        self.assertEqual(response.status_code, 200)

    def test_lookup_is_branch_scoped_for_operator_and_global_for_super_admin(self) -> None:
        operator_response = self.client.get(
            '/api/v1/admin/tickets/lookup',
            headers=self._headers('operator@example.com'),
            params={'query': '+77070000001'},
        )
        self.assertEqual(operator_response.status_code, 200)
        self.assertEqual([item['branchId'] for item in operator_response.json()['items']], ['branch-a'])

        super_response = self.client.get(
            '/api/v1/admin/tickets/lookup',
            headers=self._headers('super@example.com'),
            params={'query': '+77070000001'},
        )
        self.assertEqual(super_response.status_code, 200)
        self.assertEqual(
            {item['branchId'] for item in super_response.json()['items']},
            {'branch-a', 'branch-b'},
        )

    def test_staff_assignment_is_super_admin_only_and_validates_branch(self) -> None:
        self.assertEqual(
            self.client.get('/api/v1/admin/staff', headers=self._headers('operator@example.com')).status_code,
            403,
        )
        self.assertEqual(
            self.client.patch(
                '/api/v1/admin/staff/admin-operator/branch',
                headers=self._headers('operator@example.com'),
                json={'branch_id': 'branch-b'},
            ).status_code,
            403,
        )
        listed = self.client.get('/api/v1/admin/staff', headers=self._headers('super@example.com'))
        self.assertEqual(listed.status_code, 200)
        operator = next(item for item in listed.json()['items'] if item['id'] == 'admin-operator')
        self.assertEqual(operator['branch_id'], 'branch-a')

        updated = self.client.patch(
            '/api/v1/admin/staff/admin-operator/branch',
            headers=self._headers('super@example.com'),
            json={'branch_id': 'branch-b'},
        )
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(updated.json()['branch_id'], 'branch-b')

        missing = self.client.patch(
            '/api/v1/admin/staff/admin-operator/branch',
            headers=self._headers('super@example.com'),
            json={'branch_id': 'missing'},
        )
        self.assertEqual(missing.status_code, 404)

        with self.SessionLocal() as session:
            session.get(Branch, 'branch-b').is_active = False
            session.commit()
        inactive = self.client.patch(
            '/api/v1/admin/staff/admin-operator/branch',
            headers=self._headers('super@example.com'),
            json={'branch_id': 'branch-b'},
        )
        self.assertEqual(inactive.status_code, 400)
        self.assertEqual(inactive.json()['error']['code'], 'branch_inactive')


if __name__ == '__main__':
    unittest.main()
