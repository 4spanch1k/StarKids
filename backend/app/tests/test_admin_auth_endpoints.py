import unittest

from fastapi import Depends
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.security.passwords import hash_password
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.main import app
from app.modules.admin_auth.dependencies import require_admin_roles
from app.modules.admin_auth.schemas import AdminCurrentUserResponse

ROLE_PROBE_PATH = '/api/v1/test-only/admin/super-admin'


def _register_role_probe_route() -> None:
    if any(route.path == ROLE_PROBE_PATH for route in app.routes):
        return

    @app.get(ROLE_PROBE_PATH)
    def super_admin_probe(
        _: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')),
    ) -> dict[str, bool]:
        return {'ok': True}


class AdminAuthEndpointTests(unittest.TestCase):
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
        _register_role_probe_route()
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(AdminSession).delete()
            session.query(AdminUser).delete()
            session.add_all(
                [
                    AdminUser(
                        id='admin-super',
                        email='admin@starkids.kz',
                        full_name='Platform Admin',
                        password_hash=hash_password('StrongPass123!'),
                        role='super_admin',
                        is_active=True,
                    ),
                    AdminUser(
                        id='admin-operator',
                        email='operator@starkids.kz',
                        full_name='Lead Operator',
                        password_hash=hash_password('OperatorPass123!'),
                        role='operator',
                        is_active=True,
                    ),
                ]
            )
            session.commit()

    def test_login_returns_tokens_and_user_payload(self) -> None:
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={
                'email': 'admin@starkids.kz',
                'password': 'StrongPass123!',
            },
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['token_type'], 'bearer')
        self.assertTrue(body['access_token'])
        self.assertTrue(body['refresh_token'])
        self.assertEqual(body['user']['email'], 'admin@starkids.kz')
        self.assertEqual(body['user']['role'], 'super_admin')
        self.assertGreater(body['expires_in_seconds'], 0)
        self.assertGreater(body['refresh_expires_in_seconds'], 0)

    def test_current_user_returns_authenticated_admin(self) -> None:
        login_response = self.client.post(
            '/api/v1/admin/auth/login',
            json={
                'email': 'admin@starkids.kz',
                'password': 'StrongPass123!',
            },
        )
        access_token = login_response.json()['access_token']

        response = self.client.get(
            '/api/v1/admin/auth/current-user',
            headers={'Authorization': f'Bearer {access_token}'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                'id': 'admin-super',
                'email': 'admin@starkids.kz',
                'full_name': 'Platform Admin',
                'role': 'super_admin',
            },
        )

    def test_refresh_rotates_refresh_token_and_keeps_session_valid(self) -> None:
        login_response = self.client.post(
            '/api/v1/admin/auth/login',
            json={
                'email': 'admin@starkids.kz',
                'password': 'StrongPass123!',
            },
        )
        body = login_response.json()

        refresh_response = self.client.post(
            '/api/v1/admin/auth/refresh',
            json={'refresh_token': body['refresh_token']},
        )

        self.assertEqual(refresh_response.status_code, 200)
        refreshed_body = refresh_response.json()
        self.assertNotEqual(refreshed_body['refresh_token'], body['refresh_token'])
        self.assertNotEqual(refreshed_body['access_token'], body['access_token'])
        self.assertEqual(refreshed_body['user']['email'], 'admin@starkids.kz')

        stale_refresh_response = self.client.post(
            '/api/v1/admin/auth/refresh',
            json={'refresh_token': body['refresh_token']},
        )
        self.assertEqual(stale_refresh_response.status_code, 401)

        current_user_response = self.client.get(
            '/api/v1/admin/auth/current-user',
            headers={'Authorization': f"Bearer {refreshed_body['access_token']}"},
        )
        self.assertEqual(current_user_response.status_code, 200)

    def test_role_guard_blocks_non_super_admin_user(self) -> None:
        login_response = self.client.post(
            '/api/v1/admin/auth/login',
            json={
                'email': 'operator@starkids.kz',
                'password': 'OperatorPass123!',
            },
        )
        access_token = login_response.json()['access_token']

        response = self.client.get(
            ROLE_PROBE_PATH,
            headers={'Authorization': f'Bearer {access_token}'},
        )

        self.assertEqual(response.status_code, 403)
