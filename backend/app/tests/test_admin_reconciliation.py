from datetime import UTC, datetime
import unittest
from types import SimpleNamespace

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
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_user import MobileUser
from app.main import app
from app.modules.admin_reconciliation.service import AdminReconciliationService


class AdminReconciliationServiceTests(unittest.TestCase):
    def test_pending_ticket_issuance_is_exposed_without_mutation_actions(self) -> None:
        payment = SimpleNamespace(
            id='payment-1', local_order_id='order-1',
            created_at=datetime(2026, 9, 18, tzinfo=UTC),
            paid_at=datetime(2026, 9, 18, 10, tzinfo=UTC),
            branch_id='branch-1', amount_tenge=5000,
            failure_reason='ticket issuance failed',
            ticket_issuance_required=True, loyalty_settlement_required=False,
        )
        user = SimpleNamespace(phone='+77000000000', email=None, id='user-1')
        branch = SimpleNamespace(name='Boom Bala')
        response = AdminReconciliationService(
            repository=SimpleNamespace(list_items=lambda: [(payment, user, branch, [])]),
        ).list_items()

        self.assertEqual(response.total, 1)
        self.assertEqual(response.items[0].issueType, 'ticket_issuance_pending')
        self.assertTrue(response.items[0].ticketIssuancePending)
        self.assertEqual(response.items[0].amountTenge, 5000)

    def test_callback_mismatch_has_priority_and_keeps_last_failure(self) -> None:
        payment = SimpleNamespace(
            id='payment-2', local_order_id='order-2',
            created_at=datetime(2026, 9, 18, tzinfo=UTC), paid_at=None,
            branch_id='branch-1', amount_tenge=5000,
            failure_reason=None, ticket_issuance_required=False,
            loyalty_settlement_required=False,
        )
        callback = SimpleNamespace(
            failure_reason='amount mismatch',
        )
        response = AdminReconciliationService(
            repository=SimpleNamespace(
                list_items=lambda: [(payment, SimpleNamespace(phone=None, email='a@example.com', id='u'), SimpleNamespace(name='B'), [callback])],
            ),
        ).list_items()

        self.assertEqual(response.items[0].issueType, 'callback_validation_mismatch')
        self.assertTrue(response.items[0].callbackMismatch)
        self.assertEqual(response.items[0].lastFailure, 'amount mismatch')


class AdminReconciliationEndpointTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            'sqlite://',
            connect_args={'check_same_thread': False},
            poolclass=StaticPool,
        )
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
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
                MobilePayment,
                MobileUser,
                Branch,
                AdminSession,
                AuthThrottleState,
                AdminUser,
            ):
                session.query(model).delete()
            password = hash_password('StrongPass123!')
            session.add_all(
                [
                    AdminUser(
                        id='reconcile-super', email='reconcile-super@example.com',
                        full_name='Super', password_hash=password,
                        role='super_admin', is_active=True,
                    ),
                    AdminUser(
                        id='reconcile-operator', email='reconcile-operator@example.com',
                        full_name='Operator', password_hash=password,
                        role='operator', is_active=True,
                    ),
                    AdminUser(
                        id='reconcile-sales', email='reconcile-sales@example.com',
                        full_name='Sales', password_hash=password,
                        role='sales_manager', is_active=True,
                    ),
                ]
            )
            session.add(
                Branch(
                    id='reconcile-branch', slug='reconcile-branch', name='Boom Bala',
                    city='Almaty', address='Test', short_label='Test',
                    working_hours='10:00 - 22:00', description='Test',
                    phone='+77070000000', whatsapp_phone='+77070000000',
                    gallery_image_urls=[], facilities=[], display_order=1, is_active=True,
                )
            )
            session.add(
                MobileUser(
                    id='reconcile-user', phone='+77070000001',
                    email='parent@example.com', is_active=True,
                )
            )
            session.flush()
            session.add(
                MobilePayment(
                    id='reconcile-payment', mobile_user_id='reconcile-user',
                    branch_id='reconcile-branch', payable_entity_type='ticket_order',
                    payable_entity_id='ticket-config', local_order_id='reconcile-order',
                    idempotency_key='reconcile-key', amount_tenge=5000,
                    currency='KZT', quantity=1, ticket_items=[], status='paid',
                    ticket_issuance_required=True, init_payload={}, callback_payload={},
                )
            )
            session.commit()

    def _headers(self, role: str) -> dict[str, str]:
        email_suffix = {
            'super_admin': 'super',
            'operator': 'operator',
            'sales_manager': 'sales',
        }[role]
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={
                'email': f'reconcile-{email_suffix}@example.com',
                'password': 'StrongPass123!',
            },
            headers={'X-Forwarded-For': f'198.51.100.{len(role) + 30}'},
        )
        self.assertEqual(response.status_code, 200)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}

    def test_super_admin_can_read_reconciliation_items(self) -> None:
        response = self.client.get(
            '/api/v1/admin/reconciliation',
            headers=self._headers('super_admin'),
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['total'], 1)
        self.assertTrue(response.json()['items'][0]['ticketIssuancePending'])

    def test_operational_roles_cannot_read_reconciliation(self) -> None:
        for role in ('operator', 'sales_manager'):
            response = self.client.get(
                '/api/v1/admin/reconciliation',
                headers=self._headers(role),
            )
            self.assertEqual(response.status_code, 403, role)

    def test_reconciliation_requires_authentication(self) -> None:
        response = self.client.get('/api/v1/admin/reconciliation')
        self.assertEqual(response.status_code, 401)


if __name__ == '__main__':
    unittest.main()
