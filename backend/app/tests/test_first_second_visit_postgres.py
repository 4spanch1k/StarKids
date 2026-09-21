"""PostgreSQL proof for durable first-to-second-visit assignment.

Run against a disposable database at Alembic head with
``FIRST_SECOND_VISIT_POSTGRES_URL``. The normal suite skips this module.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
import os
import threading
import unittest
from unittest.mock import patch
from uuid import uuid4

from sqlalchemy import create_engine, delete, select
from sqlalchemy.orm import Session, sessionmaker

from app.db.models import Base
from app.db.models.branch import Branch
from app.db.models.lifecycle_journey_execution import LifecycleJourneyExecution
from app.db.models.mobile_notification_device import MobileNotificationDevice
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.models.push_campaign import PushCampaign
from app.db.models.visit import Visit
from app.modules.admin_push_campaigns.service import PushCampaignService
from app.modules.first_second_visit.service import FirstSecondVisitService
from app.services.push.delivery_result import PushDeliveryResult


class ConfiguredDelivery:
    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        return PushDeliveryResult.ok(device_token, provider_message_id='pg-lifecycle-message')


@unittest.skipUnless(os.getenv('FIRST_SECOND_VISIT_POSTGRES_URL'), 'set FIRST_SECOND_VISIT_POSTGRES_URL')
class FirstSecondVisitPostgresConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(os.environ['FIRST_SECOND_VISIT_POSTGRES_URL'], pool_size=4, max_overflow=0, pool_pre_ping=True)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def test_two_workers_persist_one_assignment_and_one_treatment_campaign(self) -> None:
        suffix = uuid4().hex[:10]
        user_id, branch_id, session_id, device_id, visit_id = (f'journey-pg-{suffix}-{part}' for part in ('user', 'branch', 'session', 'device', 'visit'))
        now = datetime.now(UTC)
        with self.SessionLocal() as db:
            db.add(Branch(id=branch_id, slug=f'journey-pg-{suffix}', name='Journey PG', city='Almaty', address='Test', short_label='PG', working_hours='00:00-23:59', description='Test', phone='1', whatsapp_phone='1', gallery_image_urls=[], facilities=[], is_active=True))
            db.add(MobileUser(id=user_id, phone=f'+77{suffix}123456', is_active=True, onboarding_completed_at=now - timedelta(days=10)))
            db.flush()
            db.add(MobileSession(id=session_id, mobile_user_id=user_id, refresh_token_hash='hash', expires_at=now + timedelta(days=1)))
            db.flush()
            db.add(MobileNotificationDevice(id=device_id, mobile_user_id=user_id, mobile_session_id=session_id, platform='ios', push_token=f'journey-pg-token-{suffix}', permission_status='granted', notifications_enabled=True))
            db.add(Visit(id=visit_id, mobile_user_id=user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=5)))
            db.commit()

        barrier = threading.Barrier(2)

        def worker() -> None:
            with self.SessionLocal() as db:
                barrier.wait()
                with patch.object(FirstSecondVisitService, '_assign_group', return_value='treatment'):
                    FirstSecondVisitService(db, PushCampaignService(db, ConfiguredDelivery())).process(now=now)

        with ThreadPoolExecutor(max_workers=2) as executor:
            list(executor.map(lambda _: worker(), range(2)))
        try:
            with self.SessionLocal() as db:
                self.assertEqual(db.query(LifecycleJourneyExecution).filter_by(journey_key='first_to_second_visit_v1', mobile_user_id=user_id).count(), 1)
                self.assertEqual(db.query(PushCampaign).filter_by(origin='system_first_to_second_visit').count(), 1)
        finally:
            with self.SessionLocal() as db:
                db.execute(delete(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == user_id))
                db.execute(delete(PushCampaign).where(PushCampaign.origin == 'system_first_to_second_visit', PushCampaign.audience_config['user_id'].as_string() == user_id))
                db.execute(delete(Visit).where(Visit.id == visit_id))
                db.execute(delete(MobileNotificationDevice).where(MobileNotificationDevice.id == device_id))
                db.execute(delete(MobileSession).where(MobileSession.id == session_id))
                db.execute(delete(MobileUser).where(MobileUser.id == user_id))
                db.execute(delete(Branch).where(Branch.id == branch_id))
                db.commit()
