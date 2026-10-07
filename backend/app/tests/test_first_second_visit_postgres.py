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

from sqlalchemy import create_engine, delete, event, select
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

    def test_unique_race_uses_savepoint_and_preserves_prior_batch_work(self) -> None:
        """A B-user collision must not roll back A's conversion in the batch."""
        suffix = uuid4().hex[:10]
        key = f'jb{suffix}'
        branch_id = f'{key}-branch'
        a_user_id = f'{key}-a-user'
        b_user_id = f'{key}-b-user'
        a_session_id = f'{key}-a-session'
        b_session_id = f'{key}-b-session'
        a_device_id = f'{key}-a-device'
        b_device_id = f'{key}-b-device'
        a_first_visit_id = f'{key}-a-first'
        a_second_visit_id = f'{key}-a-second'
        b_first_visit_id = f'{key}-b-first'
        now = datetime.now(UTC).replace(microsecond=0)

        with self.SessionLocal() as db:
            db.add(Branch(
                id=branch_id, slug=f'journey-batch-{suffix}', name='Journey batch', city='Almaty',
                address='Test', short_label='Batch', working_hours='00:00-23:59', description='Test',
                phone='1', whatsapp_phone='1', gallery_image_urls=[], facilities=[], is_active=True,
            ))
            db.add_all([
                MobileUser(id=a_user_id, phone=f'+77{suffix}111', is_active=True, onboarding_completed_at=now - timedelta(days=20)),
                MobileUser(id=b_user_id, phone=f'+77{suffix}222', is_active=True, onboarding_completed_at=now - timedelta(days=20)),
            ])
            db.flush()
            db.add_all([
                MobileSession(id=a_session_id, mobile_user_id=a_user_id, refresh_token_hash='hash-a', expires_at=now + timedelta(days=1)),
                MobileSession(id=b_session_id, mobile_user_id=b_user_id, refresh_token_hash='hash-b', expires_at=now + timedelta(days=1)),
            ])
            db.flush()
            db.add_all([
                MobileNotificationDevice(id=a_device_id, mobile_user_id=a_user_id, mobile_session_id=a_session_id, platform='ios', push_token=f'batch-a-{suffix}', permission_status='granted', notifications_enabled=True),
                MobileNotificationDevice(id=b_device_id, mobile_user_id=b_user_id, mobile_session_id=b_session_id, platform='ios', push_token=f'batch-b-{suffix}', permission_status='granted', notifications_enabled=True),
                Visit(id=a_first_visit_id, mobile_user_id=a_user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=10)),
                Visit(id=a_second_visit_id, mobile_user_id=a_user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=2)),
                Visit(id=b_first_visit_id, mobile_user_id=b_user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=5)),
            ])
            db.flush()
            # A has already been assigned and is waiting for conversion sync.
            db.add(LifecycleJourneyExecution(
                journey_key='first_to_second_visit_v1', mobile_user_id=a_user_id, experiment_group='control',
                eligible_at=now - timedelta(days=6), anchor_visit_id=a_first_visit_id,
                anchor_visit_at=now - timedelta(days=10),
            ))
            db.commit()

        main_session = self.SessionLocal()
        rival_inserted = threading.Event()

        def insert_rival_execution_before_main_flush(session: Session, _flush_context: object, _instances: object) -> None:
            if rival_inserted.is_set() or not any(
                isinstance(item, LifecycleJourneyExecution) and item.mobile_user_id == b_user_id
                for item in session.new
            ):
                return
            with self.SessionLocal() as rival:
                rival_campaign = PushCampaign(
                    internal_name='first-to-second-visit-v1', title='Снова в Boom Bala?',
                    body='Готовы снова в Boom Bala? Новые впечатления уже ждут.', audience_type='user',
                    audience_config={'user_id': b_user_id}, destination='tickets', destination_payload={},
                    status='processing', created_by_admin_id=None, origin='system_first_to_second_visit',
                )
                rival.add(rival_campaign)
                rival.flush()
                rival.add(LifecycleJourneyExecution(
                    journey_key='first_to_second_visit_v1', mobile_user_id=b_user_id,
                    experiment_group='treatment', eligible_at=now, anchor_visit_id=b_first_visit_id,
                    anchor_visit_at=now - timedelta(days=5), push_campaign_id=rival_campaign.id,
                ))
                rival.commit()
            rival_inserted.set()

        event.listen(main_session, 'before_flush', insert_rival_execution_before_main_flush)
        try:
            with patch.object(FirstSecondVisitService, '_assign_group', return_value='treatment'):
                FirstSecondVisitService(main_session, PushCampaignService(main_session, ConfiguredDelivery())).process(now=now)
            main_session.close()

            with self.SessionLocal() as db:
                a_execution = db.scalar(select(LifecycleJourneyExecution).where(
                    LifecycleJourneyExecution.journey_key == 'first_to_second_visit_v1',
                    LifecycleJourneyExecution.mobile_user_id == a_user_id,
                ))
                b_executions = db.scalars(select(LifecycleJourneyExecution).where(
                    LifecycleJourneyExecution.journey_key == 'first_to_second_visit_v1',
                    LifecycleJourneyExecution.mobile_user_id == b_user_id,
                )).all()
                b_campaigns = db.scalars(select(PushCampaign).where(
                    PushCampaign.origin == 'system_first_to_second_visit',
                    PushCampaign.audience_config['user_id'].as_string() == b_user_id,
                )).all()
                self.assertIsNotNone(a_execution)
                self.assertEqual(a_execution.conversion_visit_id, a_second_visit_id)
                self.assertEqual(len(b_executions), 1)
                self.assertEqual(len(b_campaigns), 1)
                self.assertEqual(b_executions[0].push_campaign_id, b_campaigns[0].id)
        finally:
            event.remove(main_session, 'before_flush', insert_rival_execution_before_main_flush)
            if main_session.is_active:
                main_session.close()
            with self.SessionLocal() as db:
                db.execute(delete(LifecycleJourneyExecution).where(
                    LifecycleJourneyExecution.mobile_user_id.in_([a_user_id, b_user_id])
                ))
                campaign_ids = [row[0] for row in db.execute(select(PushCampaign.id).where(
                    PushCampaign.origin == 'system_first_to_second_visit',
                    PushCampaign.audience_config['user_id'].as_string().in_([a_user_id, b_user_id]),
                )).all()]
                if campaign_ids:
                    db.execute(delete(PushCampaign).where(PushCampaign.id.in_(campaign_ids)))
                db.execute(delete(Visit).where(Visit.id.in_([a_first_visit_id, a_second_visit_id, b_first_visit_id])))
                db.execute(delete(MobileNotificationDevice).where(MobileNotificationDevice.id.in_([a_device_id, b_device_id])))
                db.execute(delete(MobileSession).where(MobileSession.id.in_([a_session_id, b_session_id])))
                db.execute(delete(MobileUser).where(MobileUser.id.in_([a_user_id, b_user_id])))
                db.execute(delete(Branch).where(Branch.id == branch_id))
                db.commit()
