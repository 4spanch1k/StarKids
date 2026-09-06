from __future__ import annotations

import unittest
from datetime import UTC, date, datetime
from unittest.mock import PropertyMock, patch
from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.models import Base
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_notification_device import MobileNotificationDevice
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.modules.admin_push_campaigns.schemas import PushCampaignAudience, PushCampaignCreateRequest
from app.modules.admin_push_campaigns.service import PushCampaignService
from app.services.push.delivery_result import PushDeliveryResult


class FakeDelivery:
    def __init__(self) -> None:
        self.tokens: list[str] = []

    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        self.tokens.append(device_token)
        return PushDeliveryResult.ok(device_token, provider_message_id=f'msg-{len(self.tokens)}')


class PushCampaignServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine('sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)

    @classmethod
    def tearDownClass(cls) -> None:
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            for model in (MobileNotificationDevice, MobileSession, MobileChild, MobileUser):
                session.query(model).delete()
            session.commit()

    def _user(self, session: Session, *, birthday: date | None = None) -> MobileUser:
        user = MobileUser(id=uuid4().hex, phone=f'+7{uuid4().int % 10**10:010d}', is_active=True)
        session.add(user); session.flush()
        mobile_session = MobileSession(id=uuid4().hex, mobile_user_id=user.id, refresh_token_hash='hash', expires_at=datetime(2030, 1, 1, tzinfo=UTC))
        session.add(mobile_session); session.flush()
        session.add(MobileNotificationDevice(id=uuid4().hex, mobile_user_id=user.id, mobile_session_id=mobile_session.id, platform='ios', push_token=f'token-{user.id}', permission_status='granted', notifications_enabled=True))
        if birthday:
            session.add(MobileChild(id=uuid4().hex, user_id=user.id, name='Алина', birth_date=birthday, gender='unspecified'))
        session.flush()
        return user

    def test_birthday_audience_deduplicates_user_with_two_matching_children(self) -> None:
        with self.SessionLocal() as session:
            user = self._user(session, birthday=date(2020, 9, 13))
            session.add(MobileChild(id=uuid4().hex, user_id=user.id, name='Али', birth_date=date(2019, 9, 13), gender='male'))
            session.commit()
            service = PushCampaignService(session, FakeDelivery())
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                result = service.preview(PushCampaignAudience(type='birthday_in_days', days_before_birthday=7))
            self.assertEqual(result.targeted_users, 1)
            self.assertEqual(result.targeted_devices, 1)

    def test_send_snapshots_and_delivers_once_per_device(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            self._user(session)
            service = PushCampaignService(session, delivery)
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                campaign = service.create(PushCampaignCreateRequest(internal_name='test-campaign', title='Заголовок', body='Текст', audience={'type': 'all_users'}, destination='home'), 'admin-1')
                result = service.send(campaign.id)
            self.assertEqual(result.status, 'sent')
            self.assertEqual(result.sent_count, 1)
            self.assertEqual(len(delivery.tokens), 1)
            self.assertEqual(service.get(campaign.id).status, 'sent')

    def test_send_rejects_when_provider_is_not_configured(self) -> None:
        with self.SessionLocal() as session:
            service = PushCampaignService(session, FakeDelivery())
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=False):
                campaign = service.create(PushCampaignCreateRequest(internal_name='test-campaign', title='Заголовок', body='Текст', audience={'type': 'all_users'}, destination='home'), 'admin-1')
                with self.assertRaises(Exception):
                    service.send(campaign.id)
