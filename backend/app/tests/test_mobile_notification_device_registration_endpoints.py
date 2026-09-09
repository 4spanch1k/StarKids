import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.mobile_notification import MobileNotification
from app.db.models.mobile_notification_device import MobileNotificationDevice
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.main import app


class MobileNotificationDeviceRegistrationEndpointTests(unittest.TestCase):
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
            session.query(MobileNotification).delete()
            session.query(MobileNotificationDevice).delete()
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.commit()

    def test_register_device_requires_authenticated_mobile_user(self) -> None:
        response = self.client.put(
            '/api/v1/mobile/me/notification-device',
            json={
                'platform': 'android',
                'push_token': 'token-1',
                'permission_status': 'granted',
                'notifications_enabled': True,
            },
        )

        self.assertEqual(response.status_code, 401)

    def test_register_device_persists_registration_for_current_mobile_session(self) -> None:
        auth_body = self._authenticate_mobile_user('+77071234567')

        response = self.client.put(
            '/api/v1/mobile/me/notification-device',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
            json={
                'platform': 'android',
                'push_token': 'token-main',
                'permission_status': 'granted',
                'notifications_enabled': True,
            },
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['platform'], 'android')
        self.assertEqual(body['push_token'], 'token-main')
        self.assertEqual(body['permission_status'], 'granted')
        self.assertTrue(body['notifications_enabled'])
        self.assertTrue(body['created_at'])
        self.assertTrue(body['updated_at'])

        with self.SessionLocal() as session:
            device = session.scalar(select(MobileNotificationDevice))
            current_session = session.scalar(
                select(MobileSession).where(
                    MobileSession.mobile_user_id == auth_body['user']['id']
                )
            )

            self.assertIsNotNone(device)
            self.assertIsNotNone(current_session)
            self.assertEqual(device.id, body['id'])
            self.assertEqual(device.mobile_user_id, auth_body['user']['id'])
            self.assertEqual(device.mobile_session_id, current_session.id)
            self.assertEqual(device.push_token, 'token-main')

    def test_register_device_updates_token_for_current_mobile_session(self) -> None:
        auth_body = self._authenticate_mobile_user('+77072223344')

        first_response = self.client.put(
            '/api/v1/mobile/me/notification-device',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
            json={
                'platform': 'android',
                'push_token': 'token-old',
                'permission_status': 'granted',
                'notifications_enabled': True,
            },
        )
        self.assertEqual(first_response.status_code, 200)

        second_response = self.client.put(
            '/api/v1/mobile/me/notification-device',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
            json={
                'platform': 'android',
                'push_token': 'token-new',
                'permission_status': 'granted',
                'notifications_enabled': True,
            },
        )

        self.assertEqual(second_response.status_code, 200)
        self.assertEqual(
            second_response.json()['id'],
            first_response.json()['id'],
        )
        self.assertEqual(second_response.json()['push_token'], 'token-new')

        with self.SessionLocal() as session:
            devices = session.scalars(select(MobileNotificationDevice)).all()
            self.assertEqual(len(devices), 1)
            self.assertEqual(devices[0].push_token, 'token-new')

    def test_register_device_rebinds_shared_token_to_current_user_and_session(self) -> None:
        first_auth = self._authenticate_mobile_user('+77070001122')
        second_auth = self._authenticate_mobile_user('+77070002233')

        first_response = self.client.put(
            '/api/v1/mobile/me/notification-device',
            headers={'Authorization': f"Bearer {first_auth['access_token']}"},
            json={
                'platform': 'android',
                'push_token': 'token-shared',
                'permission_status': 'granted',
                'notifications_enabled': True,
            },
        )
        self.assertEqual(first_response.status_code, 200)

        second_response = self.client.put(
            '/api/v1/mobile/me/notification-device',
            headers={'Authorization': f"Bearer {second_auth['access_token']}"},
            json={
                'platform': 'android',
                'push_token': 'token-shared',
                'permission_status': 'granted',
                'notifications_enabled': True,
            },
        )
        self.assertEqual(second_response.status_code, 200)

        with self.SessionLocal() as session:
            devices = session.scalars(select(MobileNotificationDevice)).all()
            second_session = session.scalar(
                select(MobileSession).where(
                    MobileSession.mobile_user_id == second_auth['user']['id']
                )
            )

            self.assertEqual(len(devices), 1)
            self.assertIsNotNone(second_session)
            self.assertEqual(devices[0].mobile_user_id, second_auth['user']['id'])
            self.assertEqual(devices[0].mobile_session_id, second_session.id)
            self.assertEqual(devices[0].push_token, 'token-shared')

    def test_remove_device_deletes_registration_for_current_mobile_session(self) -> None:
        auth_body = self._authenticate_mobile_user('+77075550000')

        register_response = self.client.put(
            '/api/v1/mobile/me/notification-device',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
            json={
                'platform': 'android',
                'push_token': 'token-remove',
                'permission_status': 'granted',
                'notifications_enabled': True,
            },
        )
        self.assertEqual(register_response.status_code, 200)

        remove_response = self.client.delete(
            '/api/v1/mobile/me/notification-device',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
        )
        self.assertEqual(remove_response.status_code, 204)

        repeat_remove_response = self.client.delete(
            '/api/v1/mobile/me/notification-device',
            headers={'Authorization': f"Bearer {auth_body['access_token']}"},
        )
        self.assertEqual(repeat_remove_response.status_code, 204)

        with self.SessionLocal() as session:
            self.assertEqual(session.query(MobileNotificationDevice).count(), 0)

    def test_notifications_route_returns_separate_notification_history(self) -> None:
        with self.SessionLocal() as session:
            session.add_all(
                [
                    MobileNotification(
                        id='news-visible',
                        news_id='news-visible',
                        notification_type='news',
                        title='Visible notification',
                        image_url='https://cdn.example/news-visible.jpg',
                        description='Shown in notifications history.',
                        is_active=True,
                    ),
                    MobileNotification(
                        id='news-hidden',
                        news_id=None,
                        notification_type='promo',
                        title='Hidden notification',
                        image_url='https://cdn.example/news-hidden.jpg',
                        description='Should stay hidden.',
                        is_active=False,
                    ),
                ]
            )
            session.commit()

        response = self.client.get('/api/v1/mobile/notifications')

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(len(body), 1)
        self.assertEqual(body[0]['id'], 'news-visible')
        self.assertEqual(body[0]['news_id'], 'news-visible')
        self.assertEqual(body[0]['type'], 'news')
        self.assertEqual(body[0]['title'], 'Visible notification')
        self.assertEqual(body[0]['description'], 'Shown in notifications history.')
        self.assertEqual(
            body[0]['image_url'],
            'https://cdn.example/news-visible.jpg',
        )
        self.assertIn('created_at', body[0])
        self.assertFalse(body[0]['is_read'])

    def _authenticate_mobile_user(self, phone: str) -> dict[str, object]:
        response = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={
                'phone': phone,
                'code': '1234',
                'verification_id': f'otp_{phone[-4:]}',
            },
        )
        self.assertEqual(response.status_code, 200)
        return response.json()
