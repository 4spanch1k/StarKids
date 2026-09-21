from __future__ import annotations

import unittest
from datetime import UTC, datetime, timedelta
from unittest.mock import PropertyMock, patch
from uuid import uuid4

from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

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


class FakeDelivery:
    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        return PushDeliveryResult.ok(device_token, provider_message_id='test-message')


class FirstSecondVisitTests(unittest.TestCase):
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
            session.query(LifecycleJourneyExecution).delete()
            session.query(PushCampaign).delete()
            session.query(Visit).delete()
            session.query(MobileNotificationDevice).delete()
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.query(Branch).delete()
            session.add(Branch(
                id='journey-branch', slug='journey-branch', name='Journey', city='Almaty', address='Test',
                short_label='Test', working_hours='10:00-20:00', description='Test', phone='1', whatsapp_phone='1',
                gallery_image_urls=[], facilities=[], display_order=1, is_active=True,
            ))
            session.commit()

    def _user(self, session: Session, *, device: bool = True) -> MobileUser:
        user = MobileUser(
            id=uuid4().hex, phone=f'+7{uuid4().int % 10**10:010d}', is_active=True,
            onboarding_completed_at=datetime(2026, 1, 1, tzinfo=UTC),
        )
        session.add(user)
        session.flush()
        if device:
            mobile_session = MobileSession(
                id=uuid4().hex, mobile_user_id=user.id, refresh_token_hash='hash',
                expires_at=datetime(2030, 1, 1, tzinfo=UTC),
            )
            session.add(mobile_session)
            session.flush()
            session.add(MobileNotificationDevice(
                id=uuid4().hex, mobile_user_id=user.id, mobile_session_id=mobile_session.id,
                platform='ios', push_token=f'token-{user.id}', permission_status='granted', notifications_enabled=True,
            ))
        return user

    def _visit(self, session: Session, user: MobileUser, started_at: datetime) -> Visit:
        visit = Visit(
            id=uuid4().hex, mobile_user_id=user.id, branch_id='journey-branch', status='completed', started_at=started_at,
        )
        session.add(visit)
        session.flush()
        return visit

    def _service(self, session: Session) -> FirstSecondVisitService:
        return FirstSecondVisitService(session, PushCampaignService(session, FakeDelivery()))

    def test_requires_one_visit_and_four_day_window(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            too_new = self._user(session); self._visit(session, too_new, now - timedelta(days=3))
            eligible = self._user(session); self._visit(session, eligible, now - timedelta(days=4))
            old = self._user(session); self._visit(session, old, now - timedelta(days=30, seconds=1))
            session.commit()
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                self._service(session).process(now=now)
            rows = session.scalars(select(LifecycleJourneyExecution)).all()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0].mobile_user_id, eligible.id)

    def test_zero_visits_are_not_eligible(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            self._user(session)
            session.commit()
            self._service(session).process(now=now)
            self.assertEqual(session.scalar(select(func.count()).select_from(LifecycleJourneyExecution)), 0)

    def test_two_visits_and_missing_device_are_excluded(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            returning = self._user(session); self._visit(session, returning, now - timedelta(days=10)); self._visit(session, returning, now - timedelta(days=1))
            no_device = self._user(session, device=False); self._visit(session, no_device, now - timedelta(days=10))
            session.commit()
            self._service(session).process(now=now)
            self.assertEqual(session.scalar(select(func.count()).select_from(LifecycleJourneyExecution)), 0)

    def test_assignment_is_persistent_and_treatment_has_one_tickets_campaign(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session, patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
            user = self._user(session); self._visit(session, user, now - timedelta(days=5)); session.commit()
            service = self._service(session)
            with patch.object(FirstSecondVisitService, '_assign_group', return_value='treatment'):
                service.process(now=now); service.process(now=now + timedelta(minutes=1))
            execution = session.scalar(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == user.id))
            self.assertIsNotNone(execution)
            self.assertEqual(execution.experiment_group, 'treatment')
            campaigns = session.scalars(select(PushCampaign).where(PushCampaign.origin == 'system_first_to_second_visit')).all()
            self.assertEqual(len(campaigns), 1)
            self.assertEqual(campaigns[0].destination, 'tickets')

    def test_second_visit_before_dispatch_cancels_treatment(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session, patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
            user = self._user(session); self._visit(session, user, now - timedelta(days=5)); session.commit()
            with patch.object(FirstSecondVisitService, '_assign_group', return_value='treatment'):
                lifecycle = self._service(session); lifecycle.process(now=now)
            campaign = session.scalar(select(PushCampaign).where(PushCampaign.origin == 'system_first_to_second_visit'))
            self._visit(session, user, now - timedelta(days=1)); session.commit()
            self._service(session).push_campaigns.process_due()
            session.refresh(campaign)
            self.assertEqual(campaign.status, 'cancelled')
            self.assertEqual(campaign.failure_reason, 'journey_no_longer_eligible')

    def test_almaty_calendar_boundary_uses_business_date(self) -> None:
        # First visit is just under 4*24h old, but four Almaty calendar days old.
        now = datetime(2026, 9, 21, 19, 30, tzinfo=UTC)  # Sep 22 00:30 in Almaty
        first_at = datetime(2026, 9, 17, 18, 30, tzinfo=UTC)  # Sep 17 23:30 in Almaty
        with self.SessionLocal() as session:
            user = self._user(session); self._visit(session, user, first_at); session.commit()
            self._service(session).process(now=now)
            self.assertIsNotNone(session.scalar(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == user.id)))

    def test_control_is_measured_without_push(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user = self._user(session); self._visit(session, user, now - timedelta(days=5)); session.commit()
            with patch.object(FirstSecondVisitService, '_assign_group', return_value='control'):
                self._service(session).process(now=now)
            execution = session.scalar(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == user.id))
            self.assertEqual(execution.experiment_group, 'control')
            self.assertIsNone(execution.push_campaign_id)

    def test_conversion_is_recorded_once_only_inside_thirty_days(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user = self._user(session)
            first = self._visit(session, user, now - timedelta(days=10)); session.commit()
            with patch.object(FirstSecondVisitService, '_assign_group', return_value='control'):
                service = self._service(session); service.process(now=now)
            second = self._visit(session, user, now - timedelta(days=2)); session.commit()
            service.process(now=now)
            execution = session.scalar(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.first_visit_id == first.id))
            self.assertEqual(execution.conversion_visit_id, second.id)
            self.assertIsNotNone(execution.converted_at)

    def test_second_visit_after_thirty_days_is_not_conversion(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user = self._user(session)
            first = self._visit(session, user, now - timedelta(days=40)); second = self._visit(session, user, now - timedelta(days=5))
            execution = LifecycleJourneyExecution(
                journey_key='first_to_second_visit_v1', mobile_user_id=user.id, experiment_group='control',
                eligible_at=now - timedelta(days=39), first_visit_id=first.id, first_visit_at=first.started_at,
            )
            session.add(execution); session.commit()
            self._service(session).process(now=now)
            execution = session.get(LifecycleJourneyExecution, execution.id)
            self.assertIsNone(execution.converted_at)


if __name__ == '__main__':
    unittest.main()
