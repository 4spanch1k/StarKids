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
from app.db.models.push_campaign import PushCampaign
from app.db.models.push_campaign_delivery import PushCampaignDelivery
from app.db.models.push_campaign_open import PushCampaignOpen
from app.main import app
from app.services.push.dependencies import get_push_delivery
from app.services.push.dev_null_delivery_service import DevNullPushDeliveryService


class AdminPushCampaignRbacTests(unittest.TestCase):
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
        app.dependency_overrides[get_push_delivery] = DevNullPushDeliveryService
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        reset_rate_limit_state()
        with self.SessionLocal() as session:
            session.query(PushCampaignDelivery).delete()
            session.query(PushCampaignOpen).delete()
            session.query(PushCampaign).delete()
            session.query(AdminSession).delete()
            session.query(AuthThrottleState).delete()
            session.query(AdminUser).delete()
            session.add_all(
                [
                    self._admin('super', 'super@example.com', 'super_admin'),
                    self._admin('content', 'content@example.com', 'content_manager'),
                    self._admin('operator', 'operator@example.com', 'operator'),
                    self._admin('sales', 'sales@example.com', 'sales_manager'),
                ]
            )
            session.commit()

    @staticmethod
    def _admin(admin_id: str, email: str, role: str) -> AdminUser:
        return AdminUser(
            id=f'admin-{admin_id}',
            email=email,
            full_name=role,
            password_hash=hash_password('StrongPass123!'),
            role=role,
            is_active=True,
        )

    def _headers(self, role: str) -> dict[str, str]:
        emails = {
            'super_admin': 'super@example.com',
            'content_manager': 'content@example.com',
            'operator': 'operator@example.com',
            'sales_manager': 'sales@example.com',
        }
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={'email': emails[role], 'password': 'StrongPass123!'},
            headers={'X-Forwarded-For': f'198.51.100.{len(role) + 10}'},
        )
        self.assertEqual(response.status_code, 200)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}

    def test_push_campaign_list_matches_allowed_roles(self) -> None:
        for role in ('super_admin', 'content_manager'):
            response = self.client.get(
                '/api/v1/admin/push-campaigns',
                headers=self._headers(role),
            )
            self.assertEqual(response.status_code, 200, role)

    def test_push_campaign_create_allows_content_manager(self) -> None:
        response = self.client.post(
            '/api/v1/admin/push-campaigns',
            headers=self._headers('content_manager'),
            json={
                'internal_name': 'content-campaign',
                'title': 'Новости Boom Bala',
                'body': 'Новое сообщение',
                'audience': {'type': 'all_users'},
                'destination': 'home',
            },
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()['status'], 'draft')

    def test_push_campaign_denies_operator_and_sales_manager(self) -> None:
        for role in ('operator', 'sales_manager'):
            response = self.client.get(
                '/api/v1/admin/push-campaigns',
                headers=self._headers(role),
            )
            self.assertEqual(response.status_code, 403, role)

    def test_push_campaign_requires_authentication(self) -> None:
        response = self.client.get('/api/v1/admin/push-campaigns')

        self.assertEqual(response.status_code, 401)
