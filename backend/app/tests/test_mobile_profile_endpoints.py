from __future__ import annotations

import io
import struct
import tempfile
import unittest
import zlib
from datetime import date, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config.settings import Settings
from app.core.database.session import get_db_session
from app.core.storage.backend import LocalStorageBackend
from app.db.models import Base
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.main import app
from app.modules.mobile_profile.dependencies import get_mobile_profile_service
from app.modules.mobile_profile.service import MobileProfileService


def _make_minimal_png(width: int = 1, height: int = 1) -> bytes:
    """Build a minimal valid 1x1 PNG image."""
    def chunk(name: bytes, data: bytes) -> bytes:
        c = struct.pack('>I', len(data)) + name + data
        crc = struct.pack('>I', zlib.crc32(name + data) & 0xFFFFFFFF)
        return c + crc

    signature = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr = chunk(b'IHDR', ihdr_data)
    raw_row = b'\x00' + b'\xff\x00\x00' * width
    compressed = zlib.compress(raw_row * height)
    idat = chunk(b'IDAT', compressed)
    iend = chunk(b'IEND', b'')
    return signature + ihdr + idat + iend


class MobileProfileEndpointTests(unittest.TestCase):
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

        # Override profile service to use a temp directory for local storage
        cls._tmp_dir = tempfile.TemporaryDirectory()
        tmp_dir = cls._tmp_dir.name

        _test_settings = Settings(
            storage_backend='local',
            media_root=tmp_dir,
            media_url_prefix='/media',
            public_base_url='http://testserver',
        )
        _test_storage = LocalStorageBackend(
            media_root=tmp_dir,
            public_base_url='http://testserver',
            media_url_prefix='/media',
        )

        from fastapi import Depends
        from sqlalchemy.orm import Session as _Session

        from app.core.database.session import get_db_session as _get_db
        from app.db.repositories.mobile_request_history_repository import (
            MobileRequestHistoryRepository as _HistRepo,
        )
        from app.db.repositories.mobile_user_repository import (
            MobileUserRepository as _UserRepo,
        )

        def _overridden_profile_service(session: _Session = Depends(_get_db)):
            return MobileProfileService(
                user_repository=_UserRepo(session),
                request_history_repository=_HistRepo(session),
                storage=_test_storage,
                settings=_test_settings,
            )

        app.dependency_overrides[get_mobile_profile_service] = _overridden_profile_service
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)
        try:
            cls._tmp_dir.cleanup()
        except Exception:
            pass

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.commit()

    def _authenticate_email(self, email: str = 'test@example.com', password: str = 'pass123456') -> dict:
        register = self.client.post(
            '/api/v1/mobile/auth/register',
            json={'email': email, 'password': password},
        )
        self.assertEqual(register.status_code, 200, register.text)
        return register.json()

    def _auth_headers(self, auth: dict) -> dict:
        return {'Authorization': f"Bearer {auth['access_token']}"}

    def test_mobile_me_returns_profile_for_authenticated_user(self) -> None:
        auth = self._authenticate_email()
        response = self.client.get(
            '/api/v1/mobile/me',
            headers=self._auth_headers(auth),
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['id'], auth['user']['id'])
        self.assertEqual(body['email'], 'test@example.com')

    def test_patch_mobile_me_updates_and_clears_fields(self) -> None:
        auth = self._authenticate_email()
        headers = self._auth_headers(auth)

        child_dob = str(date.today() - timedelta(days=365 * 3))
        patch_response = self.client.patch(
            '/api/v1/mobile/me',
            headers=headers,
            json={
                'firstName': 'Алима',
                'lastName': 'Сейткали',
                'childBirthDate': child_dob,
            },
        )
        self.assertEqual(patch_response.status_code, 200)
        body = patch_response.json()
        self.assertEqual(body['firstName'], 'Алима')
        self.assertEqual(body['lastName'], 'Сейткали')
        self.assertEqual(body['childBirthDate'], child_dob)

        clear_response = self.client.patch(
            '/api/v1/mobile/me',
            headers=headers,
            json={'firstName': None, 'lastName': None, 'childBirthDate': None},
        )
        self.assertEqual(clear_response.status_code, 200)
        cleared = clear_response.json()
        self.assertIsNone(cleared['firstName'])
        self.assertIsNone(cleared['lastName'])
        self.assertIsNone(cleared['childBirthDate'])

    def test_patch_mobile_me_rejects_duplicate_email(self) -> None:
        self._authenticate_email('other@example.com')
        auth = self._authenticate_email('first@example.com')
        headers = self._auth_headers(auth)

        response = self.client.patch(
            '/api/v1/mobile/me',
            headers=headers,
            json={'email': 'other@example.com'},
        )
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()['error']['code'], 'email_already_in_use')

    def test_patch_mobile_me_rejects_future_child_birth_date(self) -> None:
        auth = self._authenticate_email()
        headers = self._auth_headers(auth)

        future_date = str(date.today() + timedelta(days=10))
        response = self.client.patch(
            '/api/v1/mobile/me',
            headers=headers,
            json={'childBirthDate': future_date},
        )
        self.assertEqual(response.status_code, 422)

    def test_avatar_upload_and_delete(self) -> None:
        auth = self._authenticate_email()
        headers = self._auth_headers(auth)

        png_bytes = _make_minimal_png()
        upload_response = self.client.post(
            '/api/v1/mobile/me/avatar',
            headers=headers,
            files={'file': ('avatar.png', io.BytesIO(png_bytes), 'image/png')},
        )
        self.assertEqual(upload_response.status_code, 201, upload_response.text)
        upload_body = upload_response.json()
        self.assertIn('avatarUrl', upload_body)
        self.assertTrue(upload_body['avatarUrl'])

        delete_response = self.client.delete(
            '/api/v1/mobile/me/avatar',
            headers=headers,
        )
        self.assertEqual(delete_response.status_code, 200)
        delete_body = delete_response.json()
        self.assertIsNone(delete_body.get('avatarUrl'))

    def test_avatar_upload_rejects_invalid_file_type(self) -> None:
        auth = self._authenticate_email()
        headers = self._auth_headers(auth)

        fake_content = b'not an image at all, just text'
        response = self.client.post(
            '/api/v1/mobile/me/avatar',
            headers=headers,
            files={'file': ('file.txt', io.BytesIO(fake_content), 'text/plain')},
        )
        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()['error']['code'], 'invalid_avatar')

    def test_mobile_me_requests_pagination(self) -> None:
        auth = self._authenticate_email()
        headers = self._auth_headers(auth)

        for _ in range(3):
            resp = self.client.post(
                '/api/v1/mobile/leads/contact',
                headers=headers,
                json={
                    'name': 'Test User',
                    'phone': '+77071234567',
                    'email': 'test@example.com',
                    'message': 'Тестовое сообщение.',
                },
            )
            self.assertEqual(resp.status_code, 201, resp.text)

        response = self.client.get(
            '/api/v1/mobile/me/requests',
            headers=headers,
            params={'limit': 1, 'offset': 1},
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['total'], 3)
        self.assertEqual(len(body['items']), 1)
        self.assertEqual(body['limit'], 1)
        self.assertEqual(body['offset'], 1)
