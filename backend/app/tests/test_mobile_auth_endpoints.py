import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.main import app


class MobileAuthEndpointTests(unittest.TestCase):
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
        with self.SessionLocal() as session:
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.commit()

    def test_request_otp_returns_verification_payload(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/auth/request-otp',
            json={'phone': '+7 707 123 45 67'},
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body['verification_id'].startswith('otp_'))
        self.assertEqual(body['expires_in_seconds'], 300)

    def test_verify_otp_returns_auth_response_and_persists_session(self) -> None:
        request_response = self.client.post(
            '/api/v1/mobile/auth/request-otp',
            json={'phone': '+77071234567'},
        )
        verification_id = request_response.json()['verification_id']

        response = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={
                'phone': '+77071234567',
                'code': '1234',
                'verification_id': verification_id,
            },
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['token_type'], 'bearer')
        self.assertTrue(body['access_token'])
        self.assertTrue(body['refresh_token'])
        self.assertGreater(body['expires_in_seconds'], 0)
        self.assertGreater(body['refresh_expires_in_seconds'], 0)
        self.assertEqual(body['user']['phone'], '+77071234567')
        self.assertTrue(body['user']['id'])

        with self.SessionLocal() as session:
            self.assertEqual(session.query(MobileUser).count(), 1)
            self.assertEqual(session.query(MobileSession).count(), 1)

    def test_verify_otp_keeps_legacy_token_fields_for_existing_mobile_client(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={
                'phone': '+77071234567',
                'code': '1234',
                'verification_id': 'otp_legacy_contract',
            },
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn('access_token', body)
        self.assertIn('refresh_token', body)
        self.assertIsInstance(body['access_token'], str)
        self.assertIsInstance(body['refresh_token'], str)
        self.assertTrue(body['access_token'])
        self.assertTrue(body['refresh_token'])

    def test_current_user_returns_authenticated_mobile_user(self) -> None:
        verify_response = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={
                'phone': '+77071234567',
                'code': '1234',
                'verification_id': 'otp_current_user',
            },
        )
        auth_body = verify_response.json()

        response = self.client.get(
            '/api/v1/mobile/auth/current-user',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                'id': auth_body['user']['id'],
                'phone': '+77071234567',
            },
        )

    def test_mobile_me_alias_returns_same_authenticated_mobile_user(self) -> None:
        verify_response = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={
                'phone': '+77071234567',
                'code': '1234',
                'verification_id': 'otp_me_alias',
            },
        )
        auth_body = verify_response.json()

        current_user_response = self.client.get(
            '/api/v1/mobile/auth/current-user',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
        )
        me_response = self.client.get(
            '/api/v1/mobile/me',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
        )

        self.assertEqual(current_user_response.status_code, 200)
        self.assertEqual(me_response.status_code, 200)
        self.assertEqual(me_response.json(), current_user_response.json())

    def test_refresh_rotates_refresh_token_and_keeps_session_valid(self) -> None:
        verify_response = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={
                'phone': '+77071234567',
                'code': '1234',
                'verification_id': 'otp_refresh',
            },
        )
        auth_body = verify_response.json()

        refresh_response = self.client.post(
            '/api/v1/mobile/auth/refresh',
            json={'refresh_token': auth_body['refresh_token']},
        )

        self.assertEqual(refresh_response.status_code, 200)
        refreshed_body = refresh_response.json()
        self.assertNotEqual(
            refreshed_body['refresh_token'],
            auth_body['refresh_token'],
        )
        self.assertNotEqual(
            refreshed_body['access_token'],
            auth_body['access_token'],
        )
        self.assertEqual(refreshed_body['user'], auth_body['user'])

        stale_refresh_response = self.client.post(
            '/api/v1/mobile/auth/refresh',
            json={'refresh_token': auth_body['refresh_token']},
        )
        self.assertEqual(stale_refresh_response.status_code, 401)

        current_user_response = self.client.get(
            '/api/v1/mobile/auth/current-user',
            headers={'Authorization': f"Bearer {refreshed_body['access_token']}"},
        )
        self.assertEqual(current_user_response.status_code, 200)

    def test_logout_revokes_current_session(self) -> None:
        verify_response = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={
                'phone': '+77071234567',
                'code': '1234',
                'verification_id': 'otp_logout',
            },
        )
        auth_body = verify_response.json()

        logout_response = self.client.post(
            '/api/v1/mobile/auth/logout',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
        )
        self.assertEqual(logout_response.status_code, 204)

        current_user_response = self.client.get(
            '/api/v1/mobile/auth/current-user',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
        )
        self.assertEqual(current_user_response.status_code, 401)

        refresh_response = self.client.post(
            '/api/v1/mobile/auth/refresh',
            json={'refresh_token': auth_body['refresh_token']},
        )
        self.assertEqual(refresh_response.status_code, 401)
