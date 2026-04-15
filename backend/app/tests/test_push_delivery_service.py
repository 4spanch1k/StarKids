from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.mobile_notification_device import MobileNotificationDevice
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.repositories.mobile_notification_device_repository import (
    MobileNotificationDeviceRepository,
)
from app.main import app
from app.services.push.delivery_result import PushDeliveryResult
from app.services.push.dev_null_delivery_service import DevNullPushDeliveryService
from app.services.push.push_service import PushService


class PushDeliveryResultTests(unittest.TestCase):
    def test_ok_result_is_successful(self) -> None:
        result = PushDeliveryResult.ok('token-abc')
        self.assertTrue(result.success)
        self.assertEqual(result.device_token, 'token-abc')
        self.assertIsNone(result.error_code)

    def test_failed_result_is_not_successful(self) -> None:
        result = PushDeliveryResult.failed('token-abc', 'unregistered', 'gone')
        self.assertFalse(result.success)
        self.assertEqual(result.device_token, 'token-abc')
        self.assertEqual(result.error_code, 'unregistered')
        self.assertEqual(result.error_message, 'gone')


class DevNullPushDeliveryServiceTests(unittest.TestCase):
    def test_send_always_returns_not_configured_failure(self) -> None:
        service = DevNullPushDeliveryService()
        result = service.send(
            device_token='token-xyz',
            title='Hello',
            body='World',
        )
        self.assertFalse(result.success)
        self.assertEqual(result.error_code, 'not_configured')
        self.assertEqual(result.device_token, 'token-xyz')


class PushServiceTests(unittest.TestCase):
    """Unit tests for PushService orchestration logic using a fake delivery."""

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

    @classmethod
    def tearDownClass(cls) -> None:
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(MobileNotificationDevice).delete()
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.commit()

    def _create_user_with_device(
        self, session: Session, phone: str, token: str
    ) -> tuple[MobileUser, MobileNotificationDevice]:
        from uuid import uuid4
        from datetime import datetime, UTC

        user = MobileUser(
            id=uuid4().hex,
            phone=phone,
            is_active=True,
        )
        session.add(user)
        session.flush()

        mobile_session = MobileSession(
            id=uuid4().hex,
            mobile_user_id=user.id,
            refresh_token_hash='hash',
            expires_at=datetime(2030, 1, 1, tzinfo=UTC),
        )
        session.add(mobile_session)
        session.flush()

        device = MobileNotificationDevice(
            id=uuid4().hex,
            mobile_user_id=user.id,
            mobile_session_id=mobile_session.id,
            platform='android',
            push_token=token,
            permission_status='granted',
            notifications_enabled=True,
        )
        session.add(device)
        session.commit()
        return user, device

    def test_send_to_user_calls_delivery_for_active_devices(self) -> None:
        with self.SessionLocal() as session:
            user, _ = self._create_user_with_device(session, '+77070000001', 'token-u1')

        delivery = MagicMock()
        delivery.send.return_value = PushDeliveryResult.ok('token-u1')

        with self.SessionLocal() as session:
            service = PushService(
                delivery=delivery,
                device_repository=MobileNotificationDeviceRepository(session),
            )
            results = service.send_to_user(
                user_id=user.id,
                title='Test',
                body='Body',
            )

        self.assertEqual(len(results), 1)
        delivery.send.assert_called_once_with(
            device_token='token-u1',
            title='Test',
            body='Body',
            data=None,
        )

    def test_send_to_user_returns_empty_for_user_without_devices(self) -> None:
        with self.SessionLocal() as session:
            from uuid import uuid4
            user = MobileUser(id=uuid4().hex, phone='+77079999999', is_active=True)
            session.add(user)
            session.commit()
            user_id = user.id

        delivery = MagicMock()

        with self.SessionLocal() as session:
            service = PushService(
                delivery=delivery,
                device_repository=MobileNotificationDeviceRepository(session),
            )
            results = service.send_to_user(user_id=user_id, title='Hi', body='')

        self.assertEqual(results, [])
        delivery.send.assert_not_called()

    def test_send_to_user_skips_disabled_devices(self) -> None:
        with self.SessionLocal() as session:
            user, device = self._create_user_with_device(
                session, '+77070000002', 'token-disabled'
            )
            device.notifications_enabled = False
            session.commit()

        delivery = MagicMock()

        with self.SessionLocal() as session:
            service = PushService(
                delivery=delivery,
                device_repository=MobileNotificationDeviceRepository(session),
            )
            results = service.send_to_user(user_id=user.id, title='Hi', body='')

        self.assertEqual(results, [])
        delivery.send.assert_not_called()

    def test_send_to_users_aggregates_across_multiple_users(self) -> None:
        with self.SessionLocal() as session:
            user1, _ = self._create_user_with_device(session, '+77070000003', 'token-a')
            user2, _ = self._create_user_with_device(session, '+77070000004', 'token-b')

        delivery = MagicMock()
        delivery.send.return_value = PushDeliveryResult.ok('token-a')

        with self.SessionLocal() as session:
            service = PushService(
                delivery=delivery,
                device_repository=MobileNotificationDeviceRepository(session),
            )
            results = service.send_to_users(
                user_ids=[user1.id, user2.id],
                title='Promo',
                body='New deal',
            )

        self.assertEqual(len(results), 2)
        self.assertEqual(delivery.send.call_count, 2)

    def test_notify_birthday_request_received_uses_correct_payload(self) -> None:
        with self.SessionLocal() as session:
            user, _ = self._create_user_with_device(session, '+77070000005', 'token-staff')

        delivery = MagicMock()
        delivery.send.return_value = PushDeliveryResult.ok('token-staff')

        with self.SessionLocal() as session:
            service = PushService(
                delivery=delivery,
                device_repository=MobileNotificationDeviceRepository(session),
            )
            service.notify_birthday_request_received(
                admin_user_ids=[user.id],
                branch_name='Нурсат',
                parent_name='Алия',
            )

        call_kwargs = delivery.send.call_args.kwargs
        self.assertEqual(call_kwargs['title'], 'Новая заявка на день рождения')
        self.assertIn('Алия', call_kwargs['body'])
        self.assertIn('Нурсат', call_kwargs['body'])
        self.assertEqual(call_kwargs['data'], {'event': 'birthday_request_received'})


class BirthdayRequestServiceWithPushTriggerTests(unittest.TestCase):
    """
    Verifies that BirthdayRequestService works correctly with the push service
    trigger wired in.  Uses the service layer directly (the birthday_requests
    router is not yet registered in api_router.py — see app/api/router.py).
    """

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

    @classmethod
    def tearDownClass(cls) -> None:
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        from app.db.models.branch import Branch
        from app.db.models.birthday_request import BirthdayRequest

        with self.SessionLocal() as session:
            session.query(BirthdayRequest).delete()
            session.query(Branch).delete()
            session.commit()

    def test_service_creates_request_and_triggers_push_hook(self) -> None:
        from app.db.models.branch import Branch
        from app.db.repositories.birthday_request_repository import BirthdayRequestRepository
        from app.db.repositories.branch_repository import BranchRepository
        from app.db.repositories.birthday_package_repository import BirthdayPackageRepository
        from app.modules.birthday_requests.schemas import BirthdayRequestCreate
        from app.modules.birthday_requests.service import BirthdayRequestService

        with self.SessionLocal() as session:
            branch = Branch(
                id='br-push-1',
                slug='br-push-1',
                name='Нурсат',
                city='Shymkent',
                address='ул. Тауке би 1',
                short_label='Нурсат',
                working_hours='09:00–21:00',
                description='',
                phone='+77071234567',
                whatsapp_phone='+77071234567',
                is_active=True,
            )
            session.add(branch)
            session.commit()

        with self.SessionLocal() as session:
            delivery = MagicMock()
            push_service = PushService(
                delivery=delivery,
                device_repository=MobileNotificationDeviceRepository(session),
            )
            service = BirthdayRequestService(
                request_repository=BirthdayRequestRepository(session),
                branch_repository=BranchRepository(session),
                package_repository=BirthdayPackageRepository(session),
                push_service=push_service,
            )
            result = service.create_request(
                BirthdayRequestCreate(
                    branch_id='br-push-1',
                    customer_name='Test User',
                    phone='+77071234567',
                )
            )

        self.assertIsNotNone(result.id)
        self.assertEqual(result.branch_id, 'br-push-1')
        # Push service trigger runs without error; no admin devices registered yet
        # so delivery.send is never called.
        delivery.send.assert_not_called()
