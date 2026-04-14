import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.security.passwords import verify_password
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

    def test_register_email_returns_auth_response_and_hashes_password(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'Parent@Example.com',
                'password': 'strong-pass-123',
            },
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['token_type'], 'bearer')
        self.assertTrue(body['access_token'])
        self.assertTrue(body['refresh_token'])
        self.assertEqual(body['user']['email'], 'parent@example.com')
        self.assertNotIn('phone', body['user'])

        with self.SessionLocal() as session:
            saved_user = session.query(MobileUser).one()
            self.assertEqual(saved_user.email, 'parent@example.com')
            self.assertIsNone(saved_user.phone)
            self.assertIsNotNone(saved_user.password_hash)
            self.assertNotEqual(saved_user.password_hash, 'strong-pass-123')
            self.assertTrue(
                verify_password('strong-pass-123', saved_user.password_hash or '')
            )
            self.assertEqual(session.query(MobileSession).count(), 1)

    def test_register_email_rejects_duplicate_email(self) -> None:
        first_response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
            },
        )
        self.assertEqual(first_response.status_code, 200)

        duplicate_response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'PARENT@example.com',
                'password': 'strong-pass-123',
            },
        )

        self.assertEqual(duplicate_response.status_code, 409)
        self.assertEqual(
            duplicate_response.json()['error']['code'],
            'email_already_registered',
        )

    def test_login_email_returns_auth_response_for_existing_user(self) -> None:
        register_response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
            },
        )
        self.assertEqual(register_response.status_code, 200)

        response = self.client.post(
            '/api/v1/mobile/auth/login',
            json={
                'email': 'PARENT@example.com',
                'password': 'strong-pass-123',
            },
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['user']['email'], 'parent@example.com')
        self.assertNotEqual(body['access_token'], register_response.json()['access_token'])

    def test_login_email_rejects_invalid_credentials(self) -> None:
        register_response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
            },
        )
        self.assertEqual(register_response.status_code, 200)

        response = self.client.post(
            '/api/v1/mobile/auth/login',
            json={
                'email': 'parent@example.com',
                'password': 'wrong-password',
            },
        )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()['error']['code'], 'invalid_credentials')

    def test_email_auth_me_alias_returns_current_user(self) -> None:
        register_response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
            },
        )
        auth_body = register_response.json()

        response = self.client.get(
            '/api/v1/mobile/auth/me',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                'id': auth_body['user']['id'],
                'email': 'parent@example.com',
            },
        )

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
            '/api/v1/mobile/auth/me',
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
