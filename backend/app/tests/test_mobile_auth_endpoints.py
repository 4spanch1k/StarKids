import base64
from datetime import UTC, datetime, timedelta
import hashlib
import re
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.rate_limit.service import reset_rate_limit_state
from app.core.security.passwords import (
    SCRYPT_DKLEN,
    SCRYPT_N,
    SCRYPT_P,
    SCRYPT_R,
    describe_password_hash,
    verify_password,
)
from app.db.models import Base
from app.db.models.auth_throttle_state import AuthThrottleState
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
        reset_rate_limit_state()
        with self.SessionLocal() as session:
            session.query(AuthThrottleState).delete()
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

    def test_register_email_returns_auth_response_and_hashes_password_with_argon2id(self) -> None:
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
            saved_session = session.query(MobileSession).one()
            self.assertEqual(saved_user.email, 'parent@example.com')
            self.assertIsNone(saved_user.phone)
            self.assertIsNotNone(saved_user.password_hash)
            self.assertNotEqual(saved_user.password_hash, 'strong-pass-123')
            self.assertEqual(
                describe_password_hash(saved_user.password_hash or ''),
                'argon2id',
            )
            self.assertTrue(
                verify_password('strong-pass-123', saved_user.password_hash or '')
            )
            self.assertIsNotNone(saved_user.last_login_at)
            self.assertEqual(session.query(MobileSession).count(), 1)
            self.assertNotEqual(saved_session.refresh_token_hash, body['refresh_token'])
            self.assertTrue(saved_session.refresh_token_hash.startswith('hmac-sha256$'))

    def test_register_email_rejects_duplicate_email_with_controlled_error(self) -> None:
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
        body = duplicate_response.json()
        self.assertEqual(
            body['error']['code'],
            'account_already_exists',
        )
        self.assertEqual(
            body['error']['message'],
            'Аккаунт с такими данными уже существует.',
        )

    def test_register_email_rejects_weak_password(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'password123',
            },
        )

        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()['error']['code'], 'weak_password')

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
            headers=self._login_headers('198.51.100.10'),
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['user']['email'], 'parent@example.com')
        self.assertNotEqual(body['access_token'], register_response.json()['access_token'])

    def test_login_uses_same_controlled_error_for_unknown_user_and_wrong_password(self) -> None:
        unknown_response = self.client.post(
            '/api/v1/mobile/auth/login',
            json={
                'email': 'missing@example.com',
                'password': 'strong-pass-123',
            },
            headers=self._login_headers('198.51.100.11'),
        )

        register_response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
            },
        )
        self.assertEqual(register_response.status_code, 200)

        wrong_password_response = self.client.post(
            '/api/v1/mobile/auth/login',
            json={
                'email': 'parent@example.com',
                'password': 'wrong-password',
            },
            headers=self._login_headers('198.51.100.12'),
        )

        self.assertEqual(unknown_response.status_code, 401)
        self.assertEqual(wrong_password_response.status_code, 401)
        self.assertEqual(unknown_response.json(), wrong_password_response.json())
        self.assertEqual(
            unknown_response.json()['error']['message'],
            'Неверный логин или пароль.',
        )

    def test_login_rehashes_legacy_scrypt_password_on_success(self) -> None:
        with self.SessionLocal() as session:
            session.add(
                MobileUser(
                    id='legacy-user',
                    email='legacy@example.com',
                    password_hash=self._legacy_scrypt_hash('legacy-pass-123'),
                    is_active=True,
                )
            )
            session.commit()

        response = self.client.post(
            '/api/v1/mobile/auth/login',
            json={
                'email': 'legacy@example.com',
                'password': 'legacy-pass-123',
            },
            headers=self._login_headers('198.51.100.13'),
        )

        self.assertEqual(response.status_code, 200)
        with self.SessionLocal() as session:
            saved_user = session.query(MobileUser).filter_by(id='legacy-user').one()
            self.assertEqual(
                describe_password_hash(saved_user.password_hash or ''),
                'argon2id',
            )
            self.assertTrue(
                verify_password('legacy-pass-123', saved_user.password_hash or '')
            )

    def test_login_blocks_after_five_failed_attempts_for_same_ip(self) -> None:
        self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
            },
        )

        headers = self._login_headers('203.0.113.20')
        for _ in range(4):
            response = self.client.post(
                '/api/v1/mobile/auth/login',
                json={
                    'email': 'parent@example.com',
                    'password': 'wrong-password',
                },
                headers=headers,
            )
            self.assertEqual(response.status_code, 401)
            self.assertEqual(response.json()['error']['code'], 'invalid_credentials')

        blocked_response = self.client.post(
            '/api/v1/mobile/auth/login',
            json={
                'email': 'parent@example.com',
                'password': 'wrong-password',
            },
            headers=headers,
        )

        self.assertEqual(blocked_response.status_code, 429)
        body = blocked_response.json()
        self.assertEqual(body['error']['code'], 'login_temporarily_locked')
        detail_map = self._detail_map(body['error']['details'])
        self.assertGreaterEqual(int(detail_map['retry_after_seconds']), 1)

    def test_login_requires_captcha_after_three_more_failures_post_lockout(self) -> None:
        self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
            },
        )

        headers = self._login_headers('203.0.113.21')
        for _ in range(5):
            self.client.post(
                '/api/v1/mobile/auth/login',
                json={
                    'email': 'parent@example.com',
                    'password': 'wrong-password',
                },
                headers=headers,
            )

        self._expire_lockouts()

        for _ in range(2):
            response = self.client.post(
                '/api/v1/mobile/auth/login',
                json={
                    'email': 'parent@example.com',
                    'password': 'wrong-password',
                },
                headers=headers,
            )
            self.assertEqual(response.status_code, 401)

        captcha_response = self.client.post(
            '/api/v1/mobile/auth/login',
            json={
                'email': 'parent@example.com',
                'password': 'wrong-password',
            },
            headers=headers,
        )

        self.assertEqual(captcha_response.status_code, 403)
        body = captcha_response.json()
        self.assertEqual(body['error']['code'], 'captcha_required')
        detail_map = self._detail_map(body['error']['details'])
        self.assertIn('captcha_id', detail_map)
        self.assertIn('captcha_prompt', detail_map)

    def test_login_succeeds_after_valid_captcha_in_hardened_mode(self) -> None:
        self.client.post(
            '/api/v1/mobile/auth/register',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
            },
        )

        headers = self._login_headers('203.0.113.22')
        for _ in range(5):
            self.client.post(
                '/api/v1/mobile/auth/login',
                json={
                    'email': 'parent@example.com',
                    'password': 'wrong-password',
                },
                headers=headers,
            )

        self._expire_lockouts()

        for _ in range(3):
            response = self.client.post(
                '/api/v1/mobile/auth/login',
                json={
                    'email': 'parent@example.com',
                    'password': 'wrong-password',
                },
                headers=headers,
            )

        self.assertEqual(response.status_code, 403)
        detail_map = self._detail_map(response.json()['error']['details'])
        captcha_answer = self._solve_captcha(detail_map['captcha_prompt'])

        success_response = self.client.post(
            '/api/v1/mobile/auth/login',
            json={
                'email': 'parent@example.com',
                'password': 'strong-pass-123',
                'captcha_id': detail_map['captcha_id'],
                'captcha_answer': captcha_answer,
            },
            headers=headers,
        )

        self.assertEqual(success_response.status_code, 200)
        self.assertEqual(
            success_response.json()['user']['email'],
            'parent@example.com',
        )

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

    @staticmethod
    def _login_headers(ip_address: str) -> dict[str, str]:
        return {'X-Forwarded-For': ip_address}

    @staticmethod
    def _detail_map(details: list[dict[str, str]]) -> dict[str, str]:
        return {
            detail['field']: detail['message']
            for detail in details
            if detail.get('field') and detail.get('message')
        }

    @staticmethod
    def _solve_captcha(prompt: str) -> str:
        match = re.search(r'(\d+)\s*\+\s*(\d+)', prompt)
        if match is None:
            raise AssertionError(f'Unexpected captcha prompt: {prompt}')
        return str(int(match.group(1)) + int(match.group(2)))

    def _expire_lockouts(self) -> None:
        reset_rate_limit_state()
        with self.SessionLocal() as session:
            for state in session.query(AuthThrottleState).all():
                state.lockout_until = datetime.now(UTC) - timedelta(seconds=1)
            session.commit()

    @staticmethod
    def _legacy_scrypt_hash(password: str) -> str:
        salt = b'starkids-legacy!'
        derived_key = hashlib.scrypt(
            password=password.encode('utf-8'),
            salt=salt,
            n=SCRYPT_N,
            r=SCRYPT_R,
            p=SCRYPT_P,
            dklen=SCRYPT_DKLEN,
        )
        salt_segment = base64.b64encode(salt).decode('ascii')
        hash_segment = base64.b64encode(derived_key).decode('ascii')
        return f'scrypt${SCRYPT_N}${SCRYPT_R}${SCRYPT_P}${salt_segment}${hash_segment}'
