from __future__ import annotations

from datetime import UTC, datetime, timedelta
import unittest
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
from app.modules.reactivation.service import JOURNEY_KEY, ReactivationService
from app.services.push.delivery_result import PushDeliveryResult


class FakeDelivery:
    def __init__(self) -> None:
        self.tokens: list[str] = []

    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        self.tokens.append(device_token)
        return PushDeliveryResult.ok(device_token, provider_message_id=f'reactivation-{len(self.tokens)}')


class ReactivationServiceTests(unittest.TestCase):
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
            for model in (
                LifecycleJourneyExecution,
                PushCampaign,
                Visit,
                MobileNotificationDevice,
                MobileSession,
                MobileUser,
                Branch,
            ):
                session.query(model).delete()
            session.add(Branch(
                id='reactivation-branch', slug='reactivation-branch', name='Reactivation', city='Almaty',
                address='Test', short_label='Test', working_hours='10:00-22:00', description='Test',
                phone='1', whatsapp_phone='1', gallery_image_urls=[], facilities=[], display_order=1, is_active=True,
            ))
            session.commit()

    def _user(self, session: Session, *, user_id: str | None = None, device: bool = True, active: bool = True, onboarded: bool = True) -> MobileUser:
        user = MobileUser(
            id=user_id or uuid4().hex,
            phone=f'+7{uuid4().int % 10**10:010d}',
            is_active=active,
            onboarding_completed_at=datetime(2026, 1, 1, tzinfo=UTC) if onboarded else None,
        )
        session.add(user)
        session.flush()
        if device:
            mobile_session = MobileSession(
                id=uuid4().hex,
                mobile_user_id=user.id,
                refresh_token_hash=f'hash-{user.id}',
                expires_at=datetime(2030, 1, 1, tzinfo=UTC),
            )
            session.add(mobile_session)
            session.flush()
            session.add(MobileNotificationDevice(
                id=uuid4().hex,
                mobile_user_id=user.id,
                mobile_session_id=mobile_session.id,
                platform='ios',
                push_token=f'token-{user.id}',
                permission_status='granted',
                notifications_enabled=True,
            ))
        return user

    def _visit(self, session: Session, user: MobileUser, started_at: datetime, *, visit_id: str | None = None) -> Visit:
        visit = Visit(
            id=visit_id or uuid4().hex,
            mobile_user_id=user.id,
            branch_id='reactivation-branch',
            status='completed',
            started_at=started_at,
        )
        session.add(visit)
        session.flush()
        return visit

    def _service(self, session: Session, delivery: FakeDelivery | None = None) -> ReactivationService:
        return ReactivationService(session, PushCampaignService(session, delivery or FakeDelivery()))

    def test_zero_and_one_visit_are_not_eligible(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            zero = self._user(session, user_id='zero-visit')
            one = self._user(session, user_id='one-visit')
            self._visit(session, one, now - timedelta(days=60))
            session.commit()
            self._service(session).process(now=now)
            self.assertEqual(session.scalar(select(func.count()).select_from(LifecycleJourneyExecution)), 0)
            self.assertEqual(zero.id, 'zero-visit')

    def test_lapsed_window_is_45_through_89_calendar_days(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            users: dict[int, MobileUser] = {}
            for age in (44, 45, 60, 89, 90):
                user = self._user(session, user_id=f'age-{age}')
                users[age] = user
                self._visit(session, user, now - timedelta(days=age + 10))
                self._visit(session, user, now - timedelta(days=age))
            session.commit()
            self._service(session).process(now=now)
            enrolled = {
                row.mobile_user_id
                for row in session.scalars(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.journey_key == JOURNEY_KEY))
            }
            self.assertEqual(enrolled, {users[45].id, users[60].id, users[89].id})

    def test_inactive_incomplete_onboarding_and_no_device_are_excluded(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            for key, kwargs in (
                ('inactive', {'active': False}),
                ('incomplete', {'onboarded': False}),
                ('no-device', {'device': False}),
            ):
                user = self._user(session, user_id=key, **kwargs)
                self._visit(session, user, now - timedelta(days=60))
                self._visit(session, user, now - timedelta(days=10))
            session.commit()
            self._service(session).process(now=now)
            self.assertEqual(session.scalar(select(func.count()).select_from(LifecycleJourneyExecution)), 0)

    def test_assignment_is_stable_and_control_has_no_campaign(self) -> None:
        user_id = 'stable-reactivation-user'
        self.assertEqual(ReactivationService._assign_group(user_id), ReactivationService._assign_group(user_id))
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user = self._user(session, user_id=user_id)
            self._visit(session, user, now - timedelta(days=70))
            self._visit(session, user, now - timedelta(days=60))
            session.commit()
            with patch.object(ReactivationService, '_assign_group', return_value='control'):
                self._service(session).process(now=now)
            execution = session.scalar(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == user.id))
            self.assertEqual(execution.experiment_group, 'control')
            self.assertIsNone(execution.push_campaign_id)

    def test_treatment_has_one_campaign_across_retries(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user = self._user(session, user_id='treatment-reactivation-user')
            self._visit(session, user, now - timedelta(days=70))
            self._visit(session, user, now - timedelta(days=60))
            session.commit()
            with patch.object(ReactivationService, '_assign_group', return_value='treatment'):
                service = self._service(session)
                service.process(now=now)
                service.process(now=now + timedelta(minutes=1))
            self.assertEqual(session.query(LifecycleJourneyExecution).filter_by(journey_key=JOURNEY_KEY).count(), 1)
            self.assertEqual(session.query(PushCampaign).filter_by(origin='system_reactivation').count(), 1)

    def test_new_visit_after_enrollment_is_one_conversion_and_cancels_pending_push(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            user = self._user(session, user_id='conversion-reactivation-user')
            self._visit(session, user, now - timedelta(days=70))
            self._visit(session, user, now - timedelta(days=60))
            session.commit()
            with patch.object(ReactivationService, '_assign_group', return_value='treatment'), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service = self._service(session, delivery)
                service.process(now=now)
                campaign = session.scalar(select(PushCampaign).where(PushCampaign.origin == 'system_reactivation'))
                conversion = self._visit(session, user, now + timedelta(days=5))
                session.commit()
                service.process(now=now + timedelta(days=5))
                service.push_campaigns.process_due()
            execution = session.scalar(select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.mobile_user_id == user.id))
            session.refresh(campaign)
            self.assertEqual(execution.conversion_visit_id, conversion.id)
            self.assertEqual(campaign.status, 'cancelled')
            self.assertEqual(campaign.failure_reason, 'journey_already_converted')
            self.assertEqual(delivery.tokens, [])

    def test_multiple_new_visits_still_count_one_conversion(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user = self._user(session, user_id='multi-conversion-user')
            anchor_a = self._visit(session, user, now - timedelta(days=70))
            self._visit(session, user, now - timedelta(days=60))
            execution = LifecycleJourneyExecution(
                journey_key=JOURNEY_KEY, mobile_user_id=user.id, experiment_group='control', eligible_at=now,
                anchor_visit_id=anchor_a.id, anchor_visit_at=anchor_a.started_at,
            )
            session.add(execution)
            self._visit(session, user, now + timedelta(days=1))
            self._visit(session, user, now + timedelta(days=2))
            session.commit()
            self._service(session).process(now=now + timedelta(days=2))
            session.refresh(execution)
            self.assertEqual(execution.conversion_visit_id, session.scalars(
                select(Visit).where(Visit.mobile_user_id == user.id, Visit.started_at == now + timedelta(days=1))
            ).one().id)

    def test_conversion_after_thirty_days_is_not_recorded(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user = self._user(session, user_id='late-conversion-user')
            anchor = self._visit(session, user, now - timedelta(days=70))
            self._visit(session, user, now - timedelta(days=60))
            execution = LifecycleJourneyExecution(
                journey_key=JOURNEY_KEY, mobile_user_id=user.id, experiment_group='control', eligible_at=now,
                anchor_visit_id=anchor.id, anchor_visit_at=anchor.started_at,
            )
            session.add(execution)
            self._visit(session, user, now + timedelta(days=31))
            session.commit()
            self._service(session).process(now=now + timedelta(days=31))
            session.refresh(execution)
            self.assertIsNone(execution.converted_at)

    def test_provider_outage_keeps_treatment_campaign_retryable(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user = self._user(session, user_id='provider-retry-user')
            self._visit(session, user, now - timedelta(days=70))
            self._visit(session, user, now - timedelta(days=60))
            session.commit()
            with patch.object(ReactivationService, '_assign_group', return_value='treatment'):
                service = self._service(session)
                service.process(now=now)
                with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=False):
                    service.push_campaigns.process_due()
                campaign = session.scalar(select(PushCampaign).where(PushCampaign.origin == 'system_reactivation'))
                self.assertEqual(campaign.status, 'processing')
                with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                    service.push_campaigns.process_due()
            self.assertEqual(session.query(PushCampaign).filter_by(origin='system_reactivation').count(), 1)
            self.assertEqual(session.query(PushCampaign).filter_by(status='sent').count(), 1)

    def test_report_rates_use_execution_denominators(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            for index, group in enumerate(('control', 'control', 'treatment', 'treatment', 'treatment')):
                user = self._user(session, user_id=f'report-user-{index}')
                anchor = self._visit(session, user, now - timedelta(days=70))
                self._visit(session, user, now - timedelta(days=60))
                execution = LifecycleJourneyExecution(
                    journey_key=JOURNEY_KEY, mobile_user_id=user.id, experiment_group=group, eligible_at=now,
                    anchor_visit_id=anchor.id, anchor_visit_at=anchor.started_at,
                    converted_at=now + timedelta(days=1) if index in {0, 2, 3} else None,
                )
                session.add(execution)
            session.commit()
            report = self._service(session).report()
            self.assertEqual(report.control_reactivation_rate, 0.5)
            self.assertEqual(report.treatment_reactivation_rate, 2 / 3)
            self.assertLessEqual(report.treatment_reactivation_rate, 1.0)


if __name__ == '__main__':
    unittest.main()
