from __future__ import annotations

import unittest
from datetime import UTC, date, datetime, timedelta
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
from app.db.models.push_campaign import PushCampaign
from app.db.models.push_campaign_delivery import PushCampaignDelivery
from app.db.models.visit import Visit
from app.modules.admin_push_campaigns.schemas import PushCampaignAudience, PushCampaignCreateRequest, PushCampaignUpdateRequest
from app.modules.admin_push_campaigns.service import PushCampaignService, birthday_matches_target, birthday_target_date
from app.services.push.delivery_result import PushDeliveryResult


class FakeDelivery:
    def __init__(self, results: list[PushDeliveryResult] | None = None) -> None:
        self.tokens: list[str] = []
        self.results = results or []

    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        self.tokens.append(device_token)
        if self.results:
            result = self.results.pop(0)
            return result.__class__(**{**result.__dict__, 'device_token': device_token})
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
            session.query(PushCampaignDelivery).delete()
            session.query(PushCampaign).delete()
            for model in (Visit, MobileNotificationDevice, MobileSession, MobileChild, MobileUser):
                session.query(model).delete()
            session.commit()

    def _visit(self, session: Session, user: MobileUser, started_at: datetime) -> None:
        session.add(Visit(
            id=uuid4().hex,
            mobile_payment_id=uuid4().hex,
            mobile_user_id=user.id,
            branch_id=uuid4().hex,
            status='completed',
            started_at=started_at,
        ))

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
            target = birthday_target_date(datetime.now(UTC), 7)
            user = self._user(session, birthday=date(2020, target.month, target.day))
            session.add(MobileChild(id=uuid4().hex, user_id=user.id, name='Али', birth_date=date(2019, target.month, target.day), gender='male'))
            session.commit()
            service = PushCampaignService(session, FakeDelivery())
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                result = service.preview(PushCampaignAudience(type='birthday_in_days', days_before_birthday=7))
            self.assertEqual(result.targeted_users, 1)
            self.assertEqual(result.targeted_devices, 1)

    def test_visit_segment_audience_requires_and_round_trips_segment(self) -> None:
        audience = PushCampaignAudience(type='visit_segment', visit_segment='returning')
        self.assertEqual(audience.model_dump(exclude_none=True), {'type': 'visit_segment', 'visit_segment': 'returning'})
        with self.assertRaises(ValueError):
            PushCampaignAudience(type='visit_segment')
        with self.assertRaises(ValueError):
            PushCampaignAudience(type='all_users', visit_segment='returning')

    def test_visit_segment_campaign_persists_and_restores_audience_config(self) -> None:
        with self.SessionLocal() as session:
            service = PushCampaignService(session, FakeDelivery())
            campaign = service.create(
                PushCampaignCreateRequest(
                    internal_name='segment-campaign',
                    title='t',
                    body='b',
                    audience={'type': 'visit_segment', 'visit_segment': 'dormant_60'},
                    destination='home',
                ),
                'admin-1',
            )
            self.assertEqual(service.get(campaign.id).audience.model_dump(exclude_none=True), {
                'type': 'visit_segment',
                'visit_segment': 'dormant_60',
            })

    def test_visit_segment_audience_uses_derived_visit_facts(self) -> None:
        now = datetime(2026, 9, 8, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            never = self._user(session)
            first = self._user(session)
            returning = self._user(session)
            dormant = self._user(session)
            self._visit(session, first, now - timedelta(days=1))
            self._visit(session, returning, now - timedelta(days=2))
            self._visit(session, returning, now - timedelta(days=1))
            self._visit(session, dormant, now - timedelta(days=30))
            session.commit()
            service = PushCampaignService(session, FakeDelivery())

            self.assertEqual(
                service.preview(PushCampaignAudience(type='visit_segment', visit_segment='never_visited'), now=now).targeted_users,
                1,
            )
            self.assertEqual(
                service.preview(PushCampaignAudience(type='visit_segment', visit_segment='first_visit_only'), now=now).targeted_users,
                2,
            )
            self.assertEqual(
                service.preview(PushCampaignAudience(type='visit_segment', visit_segment='returning'), now=now).targeted_users,
                1,
            )
            self.assertEqual(
                service.preview(PushCampaignAudience(type='visit_segment', visit_segment='dormant_30'), now=now).targeted_users,
                1,
            )
            self.assertNotIn(
                never.id,
                service._resolve_audience(
                    PushCampaignAudience(type='visit_segment', visit_segment='dormant_30'),
                    now=now,
                )[0],
            )

    def test_dormant_audience_thresholds_use_local_calendar_boundaries(self) -> None:
        now = datetime(2026, 9, 8, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            users_by_age = {}
            for age in (29, 30, 59, 60, 89, 90):
                user = self._user(session)
                self._visit(session, user, now - timedelta(days=age))
                users_by_age[age] = user.id
            session.commit()
            service = PushCampaignService(session, FakeDelivery())

            def ids(segment: str) -> set[str]:
                return set(service._resolve_audience(
                    PushCampaignAudience(type='visit_segment', visit_segment=segment),
                    now=now,
                )[0])

            self.assertNotIn(users_by_age[29], ids('dormant_30'))
            self.assertIn(users_by_age[30], ids('dormant_30'))
            self.assertIn(users_by_age[59], ids('dormant_30'))
            self.assertNotIn(users_by_age[59], ids('dormant_60'))
            self.assertIn(users_by_age[60], ids('dormant_60'))
            self.assertIn(users_by_age[89], ids('dormant_60'))
            self.assertNotIn(users_by_age[89], ids('dormant_90'))
            self.assertIn(users_by_age[90], ids('dormant_90'))

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
            self.assertEqual(service.get(campaign.id).status, 'draft')
            self.assertEqual(session.query(PushCampaignDelivery).filter_by(campaign_id=campaign.id).count(), 0)

    def test_disabled_scheduler_does_not_mark_due_campaign_sent(self) -> None:
        with self.SessionLocal() as session:
            campaign = PushCampaign(id=uuid4().hex, internal_name='scheduled', title='t', body='b', audience_type='all_users', audience_config={}, destination='home', destination_payload={}, status='scheduled', scheduled_at=datetime.now(UTC) - timedelta(minutes=1), created_by_admin_id='admin-1')
            session.add(campaign); session.commit()
            service = PushCampaignService(session, FakeDelivery())
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=False):
                service.process_due()
            session.refresh(campaign)
            self.assertEqual(campaign.status, 'scheduled')
            self.assertEqual(session.query(PushCampaignDelivery).count(), 0)

    def test_future_schedule_is_not_early_and_cancelled_is_skipped(self) -> None:
        with self.SessionLocal() as session:
            future = PushCampaign(id=uuid4().hex, internal_name='future', title='t', body='b', audience_type='all_users', audience_config={}, destination='home', destination_payload={}, status='scheduled', scheduled_at=datetime.now(UTC) + timedelta(minutes=10), created_by_admin_id='admin-1')
            cancelled = PushCampaign(id=uuid4().hex, internal_name='cancelled', title='t', body='b', audience_type='all_users', audience_config={}, destination='home', destination_payload={}, status='cancelled', cancelled_at=datetime.now(UTC), created_by_admin_id='admin-1')
            session.add_all([future, cancelled]); session.commit()
            service = PushCampaignService(session, FakeDelivery())
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process_due()
            self.assertEqual(session.get(PushCampaign, future.id).status, 'scheduled')
            self.assertEqual(session.query(PushCampaignDelivery).count(), 0)

    def test_campaign_is_immutable_after_processing(self) -> None:
        with self.SessionLocal() as session:
            campaign = PushCampaign(id=uuid4().hex, internal_name='immutable', title='t', body='b', audience_type='all_users', audience_config={}, destination='home', destination_payload={}, status='processing', created_by_admin_id='admin-1')
            session.add(campaign); session.commit()
            service = PushCampaignService(session, FakeDelivery())
            with self.assertRaises(Exception):
                service.update(campaign.id, PushCampaignUpdateRequest(title='changed'))
            with self.assertRaises(Exception):
                service.cancel(campaign.id)

    def test_double_send_is_terminal_and_creates_one_snapshot(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            self._user(session)
            service = PushCampaignService(session, delivery)
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                campaign = service.create(PushCampaignCreateRequest(internal_name='double-send', title='t', body='b', audience={'type': 'all_users'}, destination='home'), 'admin-1')
                service.send(campaign.id)
                with self.assertRaises(Exception):
                    service.send(campaign.id)
            self.assertEqual(session.query(PushCampaignDelivery).filter_by(campaign_id=campaign.id).count(), 1)
            self.assertEqual(len(delivery.tokens), 1)

    def test_resume_skips_sent_deliveries_after_process_crash(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            self._user(session); self._user(session)
            service = PushCampaignService(session, delivery)
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                campaign = service.create(PushCampaignCreateRequest(internal_name='resume', title='t', body='b', audience={'type': 'all_users'}, destination='home'), 'admin-1')
                service._start_snapshot(campaign.id)
                first = session.query(PushCampaignDelivery).filter_by(campaign_id=campaign.id).first()
                first.status = 'sent'; first.sent_at = datetime.now(UTC)
                session.commit()
                service._deliver_campaign(campaign.id)
            self.assertEqual(len(delivery.tokens), 1)
            self.assertEqual(session.query(PushCampaignDelivery).filter_by(campaign_id=campaign.id, status='sent').count(), 2)

    def test_transient_failures_are_bounded_and_invalid_token_is_disabled(self) -> None:
        invalid = PushDeliveryResult.failed('ignored', 'unregistered', 'gone')
        delivery = FakeDelivery([invalid])
        with self.SessionLocal() as session:
            user = self._user(session)
            service = PushCampaignService(session, delivery)
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                campaign = service.create(PushCampaignCreateRequest(internal_name='invalid', title='t', body='b', audience={'type': 'all_users'}, destination='home'), 'admin-1')
                result = service.send(campaign.id)
            self.assertEqual(result.status, 'failed')
            device = session.query(MobileNotificationDevice).filter_by(mobile_user_id=user.id).one()
            self.assertFalse(device.notifications_enabled)

    def test_transient_failures_stop_after_three_attempts(self) -> None:
        failures = [PushDeliveryResult.failed('ignored', 'send_error', 'temporary') for _ in range(3)]
        delivery = FakeDelivery(failures)
        with self.SessionLocal() as session:
            self._user(session)
            service = PushCampaignService(session, delivery)
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                campaign = service.create(PushCampaignCreateRequest(internal_name='retry', title='t', body='b', audience={'type': 'all_users'}, destination='home'), 'admin-1')
                result = service.send(campaign.id)
            row = session.query(PushCampaignDelivery).filter_by(campaign_id=campaign.id).one()
            self.assertEqual(row.attempt_count, 3)
            self.assertEqual(result.status, 'failed')

    def test_zero_recipients_and_multi_device_counts(self) -> None:
        with self.SessionLocal() as session:
            user = self._user(session)
            first_device = session.query(MobileNotificationDevice).filter_by(mobile_user_id=user.id).one()
            session.add(MobileNotificationDevice(id=uuid4().hex, mobile_user_id=user.id, mobile_session_id=uuid4().hex, platform='android', push_token='second-device', permission_status='granted', notifications_enabled=True))
            session.commit()
            service = PushCampaignService(session, FakeDelivery())
            preview = service.preview(PushCampaignAudience(type='all_users'))
            self.assertEqual((preview.targeted_users, preview.targeted_devices), (1, 2))
            self.assertEqual(session.query(PushCampaignDelivery).count(), 0)
            first_device.notifications_enabled = False
            session.commit()
            empty = service.preview(PushCampaignAudience(type='birthday_in_days', days_before_birthday=7))
            self.assertEqual((empty.targeted_users, empty.targeted_devices), (0, 0))

    def test_one_invalid_device_does_not_fail_successful_devices(self) -> None:
        results = [PushDeliveryResult.ok('ignored'), PushDeliveryResult.failed('ignored', 'unregistered', 'gone'), PushDeliveryResult.ok('ignored')]
        delivery = FakeDelivery(results)
        with self.SessionLocal() as session:
            user = self._user(session)
            session.add(MobileNotificationDevice(id=uuid4().hex, mobile_user_id=user.id, mobile_session_id=uuid4().hex, platform='android', push_token='second-device', permission_status='granted', notifications_enabled=True))
            session.add(MobileNotificationDevice(id=uuid4().hex, mobile_user_id=user.id, mobile_session_id=uuid4().hex, platform='ios', push_token='third-device', permission_status='granted', notifications_enabled=True))
            session.commit()
            service = PushCampaignService(session, delivery)
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                campaign = service.create(PushCampaignCreateRequest(internal_name='partial', title='t', body='b', audience={'type': 'all_users'}, destination='home'), 'admin-1')
                result = service.send(campaign.id)
            self.assertEqual(result.status, 'sent')
            self.assertEqual((result.sent_count, result.failed_count), (2, 1))

    def test_birthday_date_rules_cover_rollover_leap_and_timezone_boundary(self) -> None:
        self.assertTrue(birthday_matches_target(date(2019, 1, 4), date(2026, 1, 4)))
        self.assertTrue(birthday_matches_target(date(2020, 2, 29), date(2025, 2, 28)))
        self.assertTrue(birthday_matches_target(date(2020, 2, 29), date(2028, 2, 29)))
        self.assertFalse(birthday_matches_target(date(2020, 2, 28), date(2028, 2, 29)))
        utc_late = datetime(2026, 9, 5, 18, 30, tzinfo=UTC)
        self.assertEqual(birthday_target_date(utc_late, 1), date(2026, 9, 6))
