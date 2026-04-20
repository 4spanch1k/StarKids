import io
import tempfile
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config.settings import Settings
from app.core.database.session import get_db_session
from app.core.security.passwords import hash_password
from app.core.storage.backend import LocalStorageBackend
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.news import News
from app.main import app
from app.modules.admin_news.router import get_admin_news_service
from app.modules.admin_news.service import AdminNewsService
from app.modules.news.router import get_news_service
from app.modules.news.service import NewsService
from app.db.repositories.news_repository import NewsRepository


class NewsEndpointTests(unittest.TestCase):
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
        cls._temp_dir = tempfile.TemporaryDirectory()

        def override_get_db_session():
            session = cls.SessionLocal()
            try:
                yield session
            finally:
                session.close()

        def override_get_news_service():
            session = cls.SessionLocal()
            try:
                yield NewsService(repository=NewsRepository(session))
            finally:
                session.close()

        def override_get_admin_news_service():
            session = cls.SessionLocal()
            try:
                settings = Settings(
                    storage_backend='local',
                    media_root=cls._temp_dir.name,
                    media_url_prefix='/media',
                )
                storage = LocalStorageBackend(
                    media_root=cls._temp_dir.name,
                    public_base_url=None,
                    media_url_prefix='/media',
                )
                yield AdminNewsService(
                    repository=NewsRepository(session),
                    storage=storage,
                    settings=settings,
                )
            finally:
                session.close()

        app.dependency_overrides[get_db_session] = override_get_db_session
        app.dependency_overrides[get_news_service] = override_get_news_service
        app.dependency_overrides[get_admin_news_service] = (
            override_get_admin_news_service
        )
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)
        cls._temp_dir.cleanup()

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(AdminSession).delete()
            session.query(AdminUser).delete()
            session.query(News).delete()
            session.add(
                AdminUser(
                    id='admin-super',
                    email='admin@starkids.kz',
                    full_name='Platform Admin',
                    password_hash=hash_password('StrongPass123!'),
                    role='super_admin',
                    is_active=True,
                )
            )
            session.commit()

    def test_mobile_news_returns_only_active_items_sorted_newest_first(self) -> None:
        older_id = self._create_news(
            title='Older news',
            image_url='https://cdn.example/old.jpg',
            is_active=True,
        )
        newer_id = self._create_news(
            title='Latest news',
            image_url='https://cdn.example/new.jpg',
            is_active=True,
        )
        self._create_news(
            title='Hidden news',
            image_url='https://cdn.example/hidden.jpg',
            is_active=False,
        )

        response = self.client.get('/api/v1/mobile/news')

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual([item['id'] for item in body], [newer_id, older_id])
        self.assertEqual(body[0]['title'], 'Latest news')
        self.assertIn('created_at', body[0])

    def test_admin_news_crud_and_delete(self) -> None:
        create_response = self.client.post(
            '/api/v1/admin/news',
            headers=self._auth_headers(),
            json={
                'title': 'Grand reopening',
                'image_url': 'https://cdn.example/news.jpg',
                'description': 'New play zone is open now.',
                'is_active': True,
            },
        )
        self.assertEqual(create_response.status_code, 200)
        news_id = create_response.json()['id']

        list_response = self.client.get(
            '/api/v1/admin/news',
            headers=self._auth_headers(),
        )
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(len(list_response.json()), 1)

        update_response = self.client.patch(
            f'/api/v1/admin/news/{news_id}',
            headers=self._auth_headers(),
            json={
                'title': 'Updated reopening',
                'description': 'Updated description.',
                'is_active': False,
            },
        )
        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(update_response.json()['title'], 'Updated reopening')
        self.assertFalse(update_response.json()['is_active'])

        mobile_response = self.client.get('/api/v1/mobile/news')
        self.assertEqual(mobile_response.status_code, 200)
        self.assertEqual(mobile_response.json(), [])

        delete_response = self.client.delete(
            f'/api/v1/admin/news/{news_id}',
            headers=self._auth_headers(),
        )
        self.assertEqual(delete_response.status_code, 204)

        list_after_delete = self.client.get(
            '/api/v1/admin/news',
            headers=self._auth_headers(),
        )
        self.assertEqual(list_after_delete.json(), [])

    def test_admin_news_image_upload_returns_media_url(self) -> None:
        png_bytes = (
            b'\x89PNG\r\n\x1a\n'
            b'\x00\x00\x00\rIHDR'
            b'\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00'
            b'\x1f\x15\xc4\x89'
            b'\x00\x00\x00\x0cIDATx\x9cc`\x00\x00\x00\x02\x00\x01'
            b'\xe2!\xbc3'
            b'\x00\x00\x00\x00IEND\xaeB`\x82'
        )
        response = self.client.post(
            '/api/v1/admin/news/upload-image',
            headers=self._auth_headers(),
            files={'file': ('news.png', io.BytesIO(png_bytes), 'image/png')},
        )

        self.assertEqual(response.status_code, 200)
        image_url = response.json()['image_url']
        self.assertTrue(image_url.startswith('http://testserver/media/news/'))

    def _create_news(
        self,
        *,
        title: str,
        image_url: str,
        is_active: bool,
    ) -> str:
        response = self.client.post(
            '/api/v1/admin/news',
            headers=self._auth_headers(),
            json={
                'title': title,
                'image_url': image_url,
                'description': f'{title} description',
                'is_active': is_active,
            },
        )
        self.assertEqual(response.status_code, 200)
        return response.json()['id']

    def _auth_headers(self) -> dict[str, str]:
        login_response = self.client.post(
            '/api/v1/admin/auth/login',
            json={
                'email': 'admin@starkids.kz',
                'password': 'StrongPass123!',
            },
        )
        self.assertEqual(login_response.status_code, 200)
        access_token = login_response.json()['access_token']
        return {'Authorization': f'Bearer {access_token}'}
