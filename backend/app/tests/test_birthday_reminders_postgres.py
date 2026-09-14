"""PostgreSQL concurrency proof for automatic birthday reminders.

Run against a disposable database at Alembic head with
``BIRTHDAY_REMINDERS_POSTGRES_URL``. The normal suite skips this module.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, date, datetime, timedelta
import os
import threading
import unittest
from unittest.mock import patch
from uuid import uuid4

from sqlalchemy import delete, select, create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config.settings import Settings
from app.db.models.birthday_reminder import BirthdayReminder
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_notification_device import MobileNotificationDevice
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.models.push_campaign import PushCampaign
from app.db.models.push_campaign_delivery import PushCampaignDelivery
from app.modules.admin_push_campaigns.service import PushCampaignService
from app.modules.birthday_reminders.service import BirthdayReminderService
from app.services.push.delivery_result import PushDeliveryResult


class ConfiguredDelivery:
    def __init__(self) -> None:
        self.tokens: list[str] = []

    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        self.tokens.append(device_token)
        return PushDeliveryResult.ok(device_token, provider_message_id='birthday-pg-message')


class ConfiguredCampaignService(PushCampaignService):
    @property
    def provider_configured(self) -> bool:
        return True


@unittest.skipUnless(os.getenv('BIRTHDAY_REMINDERS_POSTGRES_URL'), 'BIRTHDAY_REMINDERS_POSTGRES_URL is not configured')
class BirthdayReminderPostgresConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(os.environ['BIRTHDAY_REMINDERS_POSTGRES_URL'], pool_size=6, max_overflow=0, pool_pre_ping=True)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def test_two_workers_create_one_reminder_and_campaign(self) -> None:
        suffix = uuid4().hex
        user_id = f'birthday-pg-user-{suffix[:12]}'
        session_id = f'birthday-pg-session-{suffix[:12]}'
        device_id = f'birthday-pg-device-{suffix[:12]}'
        child_id = f'birthday-pg-child-{suffix[:12]}'
        token = f'birthday-pg-token-{suffix}'
        with self.SessionLocal() as db:
            db.add(MobileUser(id=user_id, phone=f'+77{suffix[:10]}', is_active=True))
            db.flush()
            db.add(MobileSession(id=session_id, mobile_user_id=user_id, refresh_token_hash='hash', expires_at=datetime.now(UTC) + timedelta(days=1)))
            db.flush()
            db.add(MobileNotificationDevice(id=device_id, mobile_user_id=user_id, mobile_session_id=session_id, platform='ios', push_token=token, permission_status='granted', notifications_enabled=True))
            db.add(MobileChild(id=child_id, user_id=user_id, name='Алина', birth_date=date(2020, 9, 20), gender='unspecified'))
            db.commit()

        barrier = threading.Barrier(2)
        now = datetime(2026, 9, 6, 12, tzinfo=UTC)

        def worker() -> int:
            with self.SessionLocal() as db:
                barrier.wait()
                return BirthdayReminderService(
                    db,
                    ConfiguredCampaignService(db, ConfiguredDelivery()),
                ).process(now=now)

        try:
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=Settings(app_env='test', birthday_reminders_enabled=True, birthday_reminder_windows='14')):
                with ThreadPoolExecutor(max_workers=2) as executor:
                    list(executor.map(lambda _: worker(), (1, 2)))
            with self.SessionLocal() as db:
                reminders = db.scalars(select(BirthdayReminder).where(BirthdayReminder.child_id == child_id)).all()
                campaigns = db.scalars(select(PushCampaign).where(PushCampaign.origin == 'system_birthday')).all()
                self.assertEqual(len(reminders), 1)
                self.assertEqual(reminders[0].status, 'sent')
                self.assertEqual(len(campaigns), 1)
                deliveries = db.scalars(select(PushCampaignDelivery).where(PushCampaignDelivery.campaign_id == campaigns[0].id)).all()
                self.assertEqual(len(deliveries), 1)
                self.assertEqual(deliveries[0].attempt_count, 1)
        finally:
            with self.SessionLocal() as db:
                campaign_ids = db.scalars(select(PushCampaign.id).where(PushCampaign.origin == 'system_birthday')).all()
                db.execute(delete(BirthdayReminder).where(BirthdayReminder.child_id == child_id))
                if campaign_ids:
                    db.execute(delete(PushCampaignDelivery).where(PushCampaignDelivery.campaign_id.in_(campaign_ids)))
                    db.execute(delete(PushCampaign).where(PushCampaign.id.in_(campaign_ids)))
                db.execute(delete(MobileNotificationDevice).where(MobileNotificationDevice.id == device_id))
                db.execute(delete(MobileSession).where(MobileSession.id == session_id))
                db.execute(delete(MobileChild).where(MobileChild.id == child_id))
                db.execute(delete(MobileUser).where(MobileUser.id == user_id))
                db.commit()
