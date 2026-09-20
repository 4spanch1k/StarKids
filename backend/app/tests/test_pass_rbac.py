from __future__ import annotations

from datetime import UTC, datetime, timedelta
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.security.passwords import hash_password
from app.core.time.business_time import business_today
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.auth_throttle_state import AuthThrottleState
from app.db.models.branch import Branch
from app.db.models.customer_pass import CustomerPass
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.models.pass_plan import PassPlan
from app.db.models.pass_redemption import PassRedemption
from app.db.models.visit import Visit
from app.main import app
from app.modules.passes.qr_service import PassQrService


class CustomerPassRbacTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            'sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool
        )
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)
        cls._qr_secret = 'r' * 48
        import app.core.config.settings as settings_module
        cls._original_qr_secret = settings_module.get_settings().ticket_qr_secret
        settings_module.get_settings().ticket_qr_secret = cls._qr_secret

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
        import app.core.config.settings as settings_module
        settings_module.get_settings().ticket_qr_secret = cls._original_qr_secret
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            for model in (
                PassRedemption, Visit, CustomerPass, MobilePayment, PassPlan,
                MobileChild, MobileSession, MobileUser, AdminSession,
                AuthThrottleState, AdminUser, Branch,
            ):
                session.query(model).delete()
            session.add(Branch(
                id='branch-rbac', slug='rbac', name='RBAC Branch', city='Almaty',
                address='Test', short_label='RBAC', working_hours='00:00 - 23:59',
                description='Test', phone='+77000000000', whatsapp_phone='+77000000000',
                gallery_image_urls=[], facilities=[], is_active=True,
            ))
            session.add(MobileUser(id='rbac-user', email='rbac@example.com', is_active=True))
            session.add(MobileChild(
                id='rbac-child', user_id='rbac-user', name='Child',
                birth_date=business_today(), gender='unspecified',
            ))
            for role in ('super_admin', 'operator', 'content_manager'):
                session.add(AdminUser(
                    id=f'rbac-admin-{role}', email=f'{role}-rbac@example.com', full_name=role,
                    password_hash=hash_password('StrongPass123!'), role=role,
                    branch_id='branch-rbac' if role == 'operator' else None, is_active=True,
                ))
            session.add(PassPlan(
                id='rbac-plan', name='BOOM 4', price_tenge=10000,
                visit_limit=4, validity_days=30, daily_limit=1,
                branch_id=None, is_active=True,
            ))
            session.add(MobilePayment(
                id='rbac-payment', mobile_user_id='rbac-user', branch_id='branch-rbac',
                payable_entity_type='pass_purchase', payable_entity_id='rbac-plan',
                local_order_id='rbac-order', idempotency_key='rbac-payment-key',
                amount_tenge=10000, gross_amount_tenge=10000, cash_amount_tenge=10000,
                currency='KZT', quantity=1, visit_date=None, ticket_items=[], status='paid',
                init_payload={'passSnapshot': {'childId': 'rbac-child'}}, callback_payload={},
            ))
            session.add(CustomerPass(
                id='rbac-pass', mobile_user_id='rbac-user', child_id='rbac-child',
                mobile_payment_id='rbac-payment', pass_plan_id='rbac-plan',
                name_snapshot='BOOM 4', price_tenge_snapshot=10000,
                visit_limit_snapshot=4, validity_days_snapshot=30, daily_limit_snapshot=1,
                branch_id_snapshot=None, activated_at=datetime.now(UTC),
                expires_at=datetime.now(UTC) + timedelta(days=30), remaining_visits=4,
                status='active',
            ))
            session.commit()

    def _headers(self, role: str) -> dict[str, str]:
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={
                'email': f'{role}-rbac@example.com',
                'password': 'StrongPass123!',
            },
        )
        self.assertEqual(response.status_code, 200, response.text)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}

    def test_customer_pass_bulk_data_is_super_admin_only(self) -> None:
        for role in ('content_manager', 'operator'):
            response = self.client.get('/api/v1/admin/passes', headers=self._headers(role))
            self.assertEqual(response.status_code, 403, response.text)
            response = self.client.get('/api/v1/admin/passes/rbac-pass', headers=self._headers(role))
            self.assertEqual(response.status_code, 403, response.text)

        response = self.client.get('/api/v1/admin/passes', headers=self._headers('super_admin'))
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['total'], 1)

    def test_operator_scanner_can_redeem_pass_without_bulk_access(self) -> None:
        qr = PassQrService(self._qr_secret).build_payload('rbac-pass')
        response = self.client.post(
            '/api/v1/admin/admission/redeem',
            headers=self._headers('operator'),
            json={'qrPayload': qr, 'branchId': 'branch-rbac'},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['outcome'], 'redeemed')


if __name__ == '__main__':
    unittest.main()
