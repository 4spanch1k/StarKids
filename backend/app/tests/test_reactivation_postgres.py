"""PostgreSQL proof for reactivation enrollment and SAVEPOINT safety.

Run against a disposable database at Alembic head with
``REACTIVATION_POSTGRES_URL``. The normal suite skips this module.
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
from app.modules.reactivation.service import JOURNEY_KEY, ReactivationService
from app.services.push.delivery_result import PushDeliveryResult


class ConfiguredDelivery:
    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        return PushDeliveryResult.ok(device_token, provider_message_id='reactivation-pg-message')


@unittest.skipUnless(os.getenv('REACTIVATION_POSTGRES_URL'), 'set REACTIVATION_POSTGRES_URL')
class ReactivationPostgresConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(os.environ['REACTIVATION_POSTGRES_URL'], pool_size=6, max_overflow=0, pool_pre_ping=True)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def test_two_workers_create_one_execution_and_campaign(self) -> None:
        suffix = uuid4().hex[:6]
        user_id = f'reactivation-pg-{suffix}-user'
        branch_id = f'reactivation-pg-{suffix}-branch'
        session_id = f'reactivation-pg-{suffix}-session'
        device_id = f'reactivation-pg-{suffix}-device'
        anchor_id = f'reactivation-pg-{suffix}-anchor'
        last_id = f'reactivation-pg-{suffix}-last'
        now = datetime.now(UTC).replace(microsecond=0)
        with self.SessionLocal() as db:
            db.add(Branch(
                id=branch_id, slug=f'reactivation-pg-{suffix}', name='Reactivation PG', city='Almaty',
                address='Test', short_label='PG', working_hours='00:00-23:59', description='Test',
                phone='1', whatsapp_phone='1', gallery_image_urls=[], facilities=[], is_active=True,
            ))
            db.add(MobileUser(id=user_id, phone=f'+77{suffix}123456', is_active=True, onboarding_completed_at=now - timedelta(days=10)))
            db.flush()
            db.add(MobileSession(id=session_id, mobile_user_id=user_id, refresh_token_hash='hash', expires_at=now + timedelta(days=1)))
            db.flush()
            db.add(MobileNotificationDevice(id=device_id, mobile_user_id=user_id, mobile_session_id=session_id, platform='ios', push_token=f'reactivation-pg-token-{suffix}', permission_status='granted', notifications_enabled=True))
            db.add_all([
                Visit(id=anchor_id, mobile_user_id=user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=70)),
                Visit(id=last_id, mobile_user_id=user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=60)),
            ])
            db.commit()

        barrier = threading.Barrier(2)

        def worker() -> None:
            with self.SessionLocal() as db:
                barrier.wait()
                with patch.object(ReactivationService, '_assign_group', return_value='treatment'):
                    ReactivationService(db, PushCampaignService(db, ConfiguredDelivery())).process(now=now)

        try:
            with ThreadPoolExecutor(max_workers=2) as executor:
                list(executor.map(lambda _: worker(), range(2)))
            with self.SessionLocal() as db:
                self.assertEqual(db.query(LifecycleJourneyExecution).filter_by(journey_key=JOURNEY_KEY, mobile_user_id=user_id).count(), 1)
                self.assertEqual(db.query(PushCampaign).filter_by(origin='system_reactivation').count(), 1)
        finally:
            self._cleanup(user_id, branch_id, session_id, device_id, (anchor_id, last_id))

    def test_unique_race_savepoint_preserves_prior_conversion(self) -> None:
        suffix = uuid4().hex[:6]
        key = f'react-b-{suffix}'
        branch_id = f'{key}-branch'
        a_user_id, b_user_id = f'{key}-a-user', f'{key}-b-user'
        a_session_id, b_session_id = f'{key}-a-session', f'{key}-b-session'
        a_device_id, b_device_id = f'{key}-a-device', f'{key}-b-device'
        a_anchor_id, a_last_id, a_new_id = f'{key}-a-anchor', f'{key}-a-last', f'{key}-a-new'
        b_anchor_id, b_last_id = f'{key}-b-anchor', f'{key}-b-last'
        now = datetime.now(UTC).replace(microsecond=0)
        with self.SessionLocal() as db:
            db.add(Branch(id=branch_id, slug=f'{key}-slug', name='Batch', city='Almaty', address='Test', short_label='Batch', working_hours='00:00-23:59', description='Test', phone='1', whatsapp_phone='1', gallery_image_urls=[], facilities=[], is_active=True))
            db.add_all([
                MobileUser(id=a_user_id, phone=f'+77{suffix}111', is_active=True, onboarding_completed_at=now - timedelta(days=10)),
                MobileUser(id=b_user_id, phone=f'+77{suffix}222', is_active=True, onboarding_completed_at=now - timedelta(days=10)),
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
                Visit(id=a_anchor_id, mobile_user_id=a_user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=70)),
                Visit(id=a_last_id, mobile_user_id=a_user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=60)),
                Visit(id=a_new_id, mobile_user_id=a_user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=5)),
                Visit(id=b_anchor_id, mobile_user_id=b_user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=70)),
                Visit(id=b_last_id, mobile_user_id=b_user_id, branch_id=branch_id, status='completed', started_at=now - timedelta(days=60)),
            ])
            # The execution FK points at the visit rows; flush those rows
            # before inserting the pre-existing A execution.
            db.flush()
            db.add(LifecycleJourneyExecution(
                journey_key=JOURNEY_KEY, mobile_user_id=a_user_id, experiment_group='control', eligible_at=now - timedelta(days=10),
                anchor_visit_id=a_last_id, anchor_visit_at=now - timedelta(days=60),
            ))
            db.commit()

        main_session = self.SessionLocal()
        rival_inserted = threading.Event()

        def insert_rival(session: Session, _flush_context: object, _instances: object) -> None:
            if rival_inserted.is_set() or not any(
                isinstance(item, LifecycleJourneyExecution) and item.mobile_user_id == b_user_id
                for item in session.new
            ):
                return
            with self.SessionLocal() as rival:
                campaign = PushCampaign(
                    internal_name='lapsed-reactivation-v1', title='Давно вас не видели',
                    body='Заглядывайте снова в Boom Bala — новые впечатления уже ждут.',
                    audience_type='user', audience_config={'user_id': b_user_id}, destination='tickets',
                    destination_payload={}, status='processing', origin='system_reactivation',
                )
                rival.add(campaign)
                rival.flush()
                rival.add(LifecycleJourneyExecution(
                    journey_key=JOURNEY_KEY, mobile_user_id=b_user_id, experiment_group='treatment', eligible_at=now,
                    anchor_visit_id=b_last_id, anchor_visit_at=now - timedelta(days=60), push_campaign_id=campaign.id,
                ))
                rival.commit()
            rival_inserted.set()

        event.listen(main_session, 'before_flush', insert_rival)
        try:
            with patch.object(ReactivationService, '_assign_group', return_value='treatment'):
                ReactivationService(main_session, PushCampaignService(main_session, ConfiguredDelivery())).process(now=now)
            with self.SessionLocal() as db:
                a_execution = db.scalar(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == a_user_id, LifecycleJourneyExecution.journey_key == JOURNEY_KEY))
                b_execution = db.scalar(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == b_user_id, LifecycleJourneyExecution.journey_key == JOURNEY_KEY))
                self.assertEqual(a_execution.conversion_visit_id, a_new_id)
                self.assertIsNotNone(b_execution)
                self.assertEqual(db.query(PushCampaign).filter_by(origin='system_reactivation').count(), 1)
        finally:
            event.remove(main_session, 'before_flush', insert_rival)
            main_session.close()
            # B still references the shared branch, so remove B's rows before
            # deleting the branch during A cleanup.
            self._cleanup(b_user_id, branch_id, b_session_id, b_device_id, (b_anchor_id, b_last_id), keep_branch=True)
            self._cleanup(a_user_id, branch_id, a_session_id, a_device_id, (a_anchor_id, a_last_id, a_new_id))

    def _cleanup(self, user_id: str, branch_id: str, session_id: str, device_id: str, visit_ids: tuple[str, ...], *, keep_branch: bool = False) -> None:
        with self.SessionLocal() as db:
            db.execute(delete(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == user_id))
            campaign_ids = [row[0] for row in db.execute(select(PushCampaign.id).where(PushCampaign.origin == 'system_reactivation', PushCampaign.audience_config['user_id'].as_string() == user_id)).all()]
            if campaign_ids:
                db.execute(delete(PushCampaign).where(PushCampaign.id.in_(campaign_ids)))
            db.execute(delete(Visit).where(Visit.id.in_(visit_ids)))
            db.execute(delete(MobileNotificationDevice).where(MobileNotificationDevice.id == device_id))
            db.execute(delete(MobileSession).where(MobileSession.id == session_id))
            db.execute(delete(MobileUser).where(MobileUser.id == user_id))
            if not keep_branch:
                db.execute(delete(Branch).where(Branch.id == branch_id))
            db.commit()
