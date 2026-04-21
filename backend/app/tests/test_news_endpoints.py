import io
import tempfile
import unittest
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.rate_limit.service import reset_rate_limit_state
from app.core.config.settings import Settings
from app.core.database.session import get_db_session
from app.core.security.passwords import hash_password
from app.core.storage.backend import LocalStorageBackend
from app.db.models import Base
from app.db.models.mobile_notification import MobileNotification
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.news import News
from app.db.models.news_event import NewsEvent
from app.db.repositories.mobile_notification_repository import (
    MobileNotificationRepository,
)
from app.db.repositories.news_event_repository import NewsEventRepository
from app.db.repositories.news_repository import NewsRepository
from app.main import app
from app.modules.admin_news.router import get_admin_news_service
from app.modules.admin_news.service import AdminNewsService
from app.modules.news.router import get_news_service
from app.modules.news.service import NewsService


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
                yield NewsService(
                    repository=NewsRepository(session),
                    event_repository=NewsEventRepository(session),
                )
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
                    notification_repository=MobileNotificationRepository(session),
                    event_repository=NewsEventRepository(session),
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
        reset_rate_limit_state()
        with self.SessionLocal() as session:
            session.query(AdminSession).delete()
            session.query(AdminUser).delete()
            session.query(MobileNotification).delete()
            session.query(NewsEvent).delete()
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
        middle_id = self._create_news(
            title='Middle news',
            image_url='https://cdn.example/middle.jpg',
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
        self.assertEqual([item['id'] for item in body], [newer_id, middle_id, older_id])
        self.assertEqual(body[0]['title'], 'Latest news')
        self.assertIn('created_at', body[0])

        paginated_response = self.client.get('/api/v1/mobile/news?limit=1&offset=1')

        self.assertEqual(paginated_response.status_code, 200)
        paginated_body = paginated_response.json()
        self.assertEqual(len(paginated_body), 1)
        self.assertEqual(paginated_body[0]['id'], middle_id)
        self.assertEqual(paginated_body[0]['title'], 'Middle news')
        self.assertEqual(
            paginated_body[0]['image_url'],
            'https://cdn.example/middle.jpg',
        )
        self.assertEqual(
            paginated_body[0]['description'],
            'Middle news description',
        )
        self.assertIn('created_at', paginated_body[0])

    def test_mobile_news_details_and_event_logging(self) -> None:
        news_id = self._create_news(
            title='Tracked news',
            image_url='https://cdn.example/tracked.jpg',
            is_active=True,
        )

        details_response = self.client.get(f'/api/v1/mobile/news/{news_id}')

        self.assertEqual(details_response.status_code, 200)
        self.assertEqual(details_response.json()['id'], news_id)
        self.assertEqual(details_response.json()['title'], 'Tracked news')

        click_response = self.client.post(
            f'/api/v1/mobile/news/{news_id}/events',
            json={'event_type': 'click'},
        )
        view_response = self.client.post(
            f'/api/v1/mobile/news/{news_id}/events',
            json={'event_type': 'view'},
        )

        self.assertEqual(click_response.status_code, 204)
        self.assertEqual(view_response.status_code, 204)

        with self.SessionLocal() as session:
            events = session.query(NewsEvent).order_by(NewsEvent.created_at.asc()).all()

        self.assertEqual(len(events), 2)
        self.assertEqual(events[0].news_id, news_id)
        self.assertEqual(events[0].event_type, 'click')
        self.assertEqual(events[1].event_type, 'view')

    def test_mobile_news_events_are_rate_limited_after_twenty_requests_per_minute(self) -> None:
        news_id = self._create_news(
            title='Rate limited news',
            image_url='https://cdn.example/rate-limited.jpg',
            is_active=True,
        )

        responses = [
            self.client.post(
                f'/api/v1/mobile/news/{news_id}/events',
                json={'event_type': 'click'},
            )
            for _ in range(21)
        ]

        self.assertTrue(all(response.status_code == 204 for response in responses[:20]))
        self.assertEqual(responses[-1].status_code, 429)

    def test_mobile_notifications_return_news_history_with_pagination(self) -> None:
        older_id = self._create_news(
            title='History older',
            image_url='https://cdn.example/history-old.jpg',
            is_active=True,
        )
        newer_id = self._create_news(
            title='History newer',
            image_url='https://cdn.example/history-new.jpg',
            is_active=True,
        )

        response = self.client.get('/api/v1/mobile/notifications?limit=1&offset=0')

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(len(body), 1)
        self.assertEqual(body[0]['id'], newer_id)
        self.assertEqual(body[0]['news_id'], newer_id)
        self.assertEqual(body[0]['type'], 'news')
        self.assertEqual(body[0]['title'], 'History newer')
        self.assertIn('created_at', body[0])

        second_page = self.client.get('/api/v1/mobile/notifications?limit=1&offset=1')

        self.assertEqual(second_page.status_code, 200)
        self.assertEqual(second_page.json()[0]['id'], older_id)

    def test_mobile_news_hides_items_scheduled_for_future_publish(self) -> None:
        visible_id = self._create_news(
            title='Published now',
            image_url='https://cdn.example/published.jpg',
            is_active=True,
        )
        self._create_news(
            title='Future publish',
            image_url='https://cdn.example/future.jpg',
            is_active=True,
            publish_at=(datetime.now(UTC) + timedelta(days=1)).isoformat(),
        )

        response = self.client.get('/api/v1/mobile/news')

        self.assertEqual(response.status_code, 200)
        self.assertEqual([item['id'] for item in response.json()], [visible_id])

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

    def test_admin_news_stats_endpoints_return_ctr_and_top_news(self) -> None:
        first_news_id = self._create_news(
            title='Top stats news',
            image_url='https://cdn.example/top.jpg',
            is_active=True,
        )
        second_news_id = self._create_news(
            title='Second stats news',
            image_url='https://cdn.example/second.jpg',
            is_active=True,
        )

        for _ in range(3):
            self.client.post(
                f'/api/v1/mobile/news/{first_news_id}/events',
                json={'event_type': 'view'},
                headers={'X-Forwarded-For': f'198.51.100.{10 + _}'},
            )
        self.client.post(
            f'/api/v1/mobile/news/{first_news_id}/events',
            json={'event_type': 'click'},
            headers={'X-Forwarded-For': '198.51.100.20'},
        )
        self.client.post(
            f'/api/v1/mobile/news/{second_news_id}/events',
            json={'event_type': 'view'},
            headers={'X-Forwarded-For': '198.51.100.30'},
        )

        stats_response = self.client.get(
            f'/api/v1/admin/news/{first_news_id}/stats',
            headers=self._auth_headers(),
        )
        top_response = self.client.get(
            '/api/v1/admin/news/stats/top',
            headers=self._auth_headers(),
        )

        self.assertEqual(stats_response.status_code, 200)
        self.assertEqual(
            stats_response.json(),
            {
                'views_count': 3,
                'clicks_count': 1,
                'ctr': 0.3333,
            },
        )

        self.assertEqual(top_response.status_code, 200)
        top_body = top_response.json()
        self.assertEqual(top_body['last_24_hours'][0]['news_id'], first_news_id)
        self.assertEqual(top_body['last_24_hours'][0]['views_count'], 3)
        self.assertEqual(top_body['last_7_days'][0]['news_id'], first_news_id)

    def test_admin_news_rejects_title_longer_than_80_characters(self) -> None:
        response = self.client.post(
            '/api/v1/admin/news',
            headers=self._auth_headers(),
            json={
                'title': 'x' * 81,
                'image_url': 'https://cdn.example/news.jpg',
                'description': 'Long title should be rejected.',
                'is_active': True,
            },
        )

        self.assertEqual(response.status_code, 422)

    def test_admin_news_rejects_blank_description(self) -> None:
        response = self.client.post(
            '/api/v1/admin/news',
            headers=self._auth_headers(),
            json={
                'title': 'Blank description',
                'image_url': 'https://cdn.example/news.jpg',
                'description': '   ',
                'is_active': True,
            },
        )

        self.assertEqual(response.status_code, 422)

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
        publish_at: str | None = None,
    ) -> str:
        response = self.client.post(
            '/api/v1/admin/news',
            headers=self._auth_headers(),
            json={
                'title': title,
                'image_url': image_url,
                'description': f'{title} description',
                'is_active': is_active,
                'publish_at': publish_at,
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
