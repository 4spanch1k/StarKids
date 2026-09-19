"""PostgreSQL proof for concurrent campaign workers.

Run against a disposable database at Alembic head with
``PUSH_CAMPAIGNS_POSTGRES_URL``. The normal SQLite suite skips this module.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
import os
import threading
import unittest
from uuid import uuid4

from sqlalchemy import create_engine, delete, select
from sqlalchemy.orm import Session, sessionmaker

from app.db.models.admin_user import AdminUser
from app.db.models.mobile_notification_device import MobileNotificationDevice
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.models.push_campaign import PushCampaign
from app.db.models.push_campaign_delivery import PushCampaignDelivery
from app.modules.admin_push_campaigns.service import PushCampaignService
from app.services.push.delivery_result import PushDeliveryResult


class ConfiguredFakeDelivery:
    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        return PushDeliveryResult.ok(device_token, provider_message_id='pg-message')


class ConfiguredCampaignService(PushCampaignService):
    @property
    def provider_configured(self) -> bool:
        return True


@unittest.skipUnless(os.getenv('PUSH_CAMPAIGNS_POSTGRES_URL'), 'set PUSH_CAMPAIGNS_POSTGRES_URL')
class PushCampaignPostgresConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(os.environ['PUSH_CAMPAIGNS_POSTGRES_URL'], pool_size=6, max_overflow=0, pool_pre_ping=True)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def test_two_workers_create_one_snapshot_and_send_once(self) -> None:
        suffix = uuid4().hex
        user_id = f'pg-campaign-user-{suffix[:12]}'
        admin_id = f'pg-campaign-admin-{suffix[:12]}'
        session_id = f'pg-campaign-session-{suffix[:12]}'
        device_id = f'pg-campaign-device-{suffix[:12]}'
        campaign_id = f'pg-campaign-{suffix[:12]}'
        token = f'pg-token-{suffix}'
        with self.SessionLocal() as db:
            db.add(AdminUser(id=admin_id, email=f'{suffix}@admin.example.com', full_name='PG', password_hash='x', role='super_admin', is_active=True))
            db.add(MobileUser(id=user_id, phone=f'+77{suffix[:10]}', is_active=True))
            db.flush()
            db.add(MobileSession(id=session_id, mobile_user_id=user_id, refresh_token_hash='hash', expires_at=datetime.now(UTC) + timedelta(days=1)))
            db.flush()
            db.add(MobileNotificationDevice(id=device_id, mobile_user_id=user_id, mobile_session_id=session_id, platform='ios', push_token=token, permission_status='granted', notifications_enabled=True))
            db.add(PushCampaign(id=campaign_id, internal_name='pg-concurrent', title='t', body='b', audience_type='all_users', audience_config={}, destination='home', destination_payload={}, status='scheduled', scheduled_at=datetime.now(UTC) - timedelta(minutes=1), created_by_admin_id=admin_id))
            db.commit()

        barrier = threading.Barrier(2)

        def worker() -> int:
            with self.SessionLocal() as db:
                barrier.wait()
                return ConfiguredCampaignService(db, ConfiguredFakeDelivery()).process_due()

        try:
            with ThreadPoolExecutor(max_workers=2) as executor:
                list(executor.map(lambda _: worker(), (1, 2)))
            with self.SessionLocal() as db:
                campaign = db.get(PushCampaign, campaign_id)
                deliveries = db.scalars(select(PushCampaignDelivery).where(PushCampaignDelivery.campaign_id == campaign_id)).all()
                self.assertEqual(campaign.status, 'sent')
                self.assertEqual(len(deliveries), 1)
                self.assertEqual(deliveries[0].status, 'sent')
                self.assertEqual(deliveries[0].attempt_count, 1)
        finally:
            with self.SessionLocal() as db:
                db.execute(delete(PushCampaignDelivery).where(PushCampaignDelivery.campaign_id == campaign_id))
                db.execute(delete(PushCampaign).where(PushCampaign.id == campaign_id))
                db.execute(delete(MobileNotificationDevice).where(MobileNotificationDevice.id == device_id))
                db.execute(delete(MobileSession).where(MobileSession.id == session_id))
                db.execute(delete(MobileUser).where(MobileUser.id == user_id))
                db.execute(delete(AdminUser).where(AdminUser.id == admin_id))
                db.commit()
