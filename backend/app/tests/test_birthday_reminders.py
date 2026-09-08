from __future__ import annotations

import unittest
from datetime import UTC, date, datetime
from unittest.mock import PropertyMock, patch
from uuid import uuid4

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config.settings import Settings
from app.db.models import Base
from app.db.models.birthday_reminder import BirthdayReminder
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_notification_device import MobileNotificationDevice
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.models.push_campaign import PushCampaign
from app.modules.admin_push_campaigns.service import PushCampaignService
from app.modules.birthday_reminders.service import BirthdayReminderService, birthday_target_date
from app.services.push.delivery_result import PushDeliveryResult


class FakeDelivery:
    def __init__(self) -> None:
        self.tokens: list[str] = []

    def send(self, *, device_token: str, title: str, body: str, data: dict[str, str] | None = None) -> PushDeliveryResult:
        self.tokens.append(device_token)
        return PushDeliveryResult.ok(device_token, provider_message_id=f'message-{len(self.tokens)}')


class BirthdayReminderServiceTests(unittest.TestCase):
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
            for model in (BirthdayReminder, PushCampaign, BirthdayRequest, MobileNotificationDevice, MobileSession, MobileChild, MobileUser):
                session.query(model).delete()
            session.commit()

    def _user(self, session: Session, *, birth_date: date | None, devices: int = 1) -> tuple[MobileUser, MobileChild | None]:
        user = MobileUser(id=uuid4().hex, phone=f'+7{uuid4().int % 10**10:010d}', is_active=True)
        session.add(user)
        session.flush()
        child = None
        if birth_date:
            child = MobileChild(id=uuid4().hex, user_id=user.id, name='Алина', birth_date=birth_date, gender='unspecified')
            session.add(child)
        for index in range(devices):
            mobile_session = MobileSession(
                id=uuid4().hex,
                mobile_user_id=user.id,
                refresh_token_hash=f'hash-{index}',
                expires_at=datetime(2030, 1, 1, tzinfo=UTC),
            )
            session.add(mobile_session)
            session.flush()
            session.add(MobileNotificationDevice(
                id=uuid4().hex,
                mobile_user_id=user.id,
                mobile_session_id=mobile_session.id,
                platform='ios',
                push_token=f'token-{user.id}-{index}',
                permission_status='granted',
                notifications_enabled=True,
            ))
        session.commit()
        return user, child

    def _settings(self, *, enabled: bool = True, windows: str = '14,7,1') -> Settings:
        return Settings(
            app_env='test',
            birthday_reminders_enabled=enabled,
            birthday_reminder_windows=windows,
        )

    def _service(self, session: Session, delivery: FakeDelivery) -> BirthdayReminderService:
        return BirthdayReminderService(session, PushCampaignService(session, delivery))

    def test_windows_and_timezone_use_shared_birthday_semantics(self) -> None:
        self.assertEqual(
            birthday_target_date(datetime(2026, 9, 5, 18, 30, tzinfo=UTC), 1),
            date(2026, 9, 6),
        )
        self.assertEqual(
            birthday_target_date(datetime(2026, 12, 18, 12, tzinfo=UTC), 14),
            date(2027, 1, 1),
        )

    def test_one_parent_with_twins_gets_one_campaign(self) -> None:
        delivery = FakeDelivery()
        now = datetime(2026, 9, 6, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user, first = self._user(session, birth_date=date(2020, 9, 20))
            session.add(MobileChild(id=uuid4().hex, user_id=user.id, name='Али', birth_date=date(2019, 9, 20), gender='male'))
            session.commit()
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=now)
            reminders = session.scalars(select(BirthdayReminder)).all()
            self.assertEqual(len(reminders), 2)
            self.assertTrue(all(item.status == 'sent' for item in reminders))
            self.assertEqual(session.query(PushCampaign).count(), 1)
            self.assertEqual(len(delivery.tokens), 1)
            self.assertEqual(first.birth_date, date(2020, 9, 20))

    def test_all_three_windows_create_one_campaign_each(self) -> None:
        delivery = FakeDelivery()
        now = datetime(2026, 9, 6, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            user, _ = self._user(session, birth_date=date(2020, 9, 20))
            session.add_all([
                MobileChild(id=uuid4().hex, user_id=user.id, name='Семь', birth_date=date(2019, 9, 13), gender='unspecified'),
                MobileChild(id=uuid4().hex, user_id=user.id, name='Один', birth_date=date(2018, 9, 7), gender='unspecified'),
            ])
            session.commit()
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings()), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=now)
            self.assertEqual(session.query(BirthdayReminder).count(), 3)
            self.assertEqual(session.query(PushCampaign).count(), 3)
            self.assertEqual(len(delivery.tokens), 3)

    def test_wrong_day_and_february_29_policy_match_shared_calculator(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            self._user(session, birth_date=date(2020, 9, 21))
            service = self._service(session, delivery)
            settings = self._settings(windows='14')
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=settings), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            self.assertEqual(session.query(BirthdayReminder).count(), 0)

        with self.SessionLocal() as session:
            self._user(session, birth_date=date(2020, 2, 29))
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 2, 14, 12, tzinfo=UTC))
            self.assertEqual(session.query(BirthdayReminder).count(), 1)

    def test_retry_after_campaign_creation_resumes_without_second_campaign(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            user, child = self._user(session, birth_date=date(2020, 9, 20))
            push = PushCampaignService(session, delivery)
            with patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                campaign = push.create_system_birthday_campaign(
                    user_id=user.id,
                    internal_name='birthday-reminder-crash-resume',
                    title='title',
                    body='body',
                )
            reminder = BirthdayReminder(
                child_id=child.id,
                mobile_user_id=user.id,
                birthday_year=2026,
                days_before=14,
                push_campaign_id=campaign.id,
            )
            session.add(reminder)
            session.commit()
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            self.assertEqual(session.query(PushCampaign).count(), 1)
            self.assertEqual(len(delivery.tokens), 1)
            self.assertEqual(session.query(BirthdayReminder).one().status, 'sent')

    def test_active_lead_suppresses_acquisition_reminder(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            user, child = self._user(session, birth_date=date(2020, 9, 20))
            session.add(BirthdayRequest(
                id=uuid4().hex,
                mobile_user_id=user.id,
                branch_id='branch-1',
                customer_name='Parent',
                phone='+77000000000',
                child_id=child.id,
                status='new',
            ))
            session.commit()
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            reminder = session.query(BirthdayReminder).one()
            self.assertEqual(reminder.status, 'skipped')
            self.assertEqual(reminder.skip_reason, 'active_lead')
            self.assertEqual(len(delivery.tokens), 0)

    def test_qualified_and_booked_leads_suppress_acquisition_reminder(self) -> None:
        for status in ('qualified', 'booked'):
            delivery = FakeDelivery()
            with self.SessionLocal() as session:
                user, child = self._user(session, birth_date=date(2020, 9, 20))
                session.add(BirthdayRequest(
                    id=uuid4().hex,
                    mobile_user_id=user.id,
                    branch_id='branch-1',
                    customer_name='Parent',
                    phone='+77000000000',
                    child_id=child.id,
                    status=status,
                ))
                session.commit()
                service = self._service(session, delivery)
                with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                     patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                    service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
                reminder = session.query(BirthdayReminder).filter(BirthdayReminder.child_id == child.id).one()
                self.assertEqual(reminder.skip_reason, 'active_lead')
                self.assertEqual(len(delivery.tokens), 0)

    def test_completed_lead_suppresses_same_birthday_date(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            user, child = self._user(session, birth_date=date(2020, 9, 20))
            session.add(BirthdayRequest(
                id=uuid4().hex,
                mobile_user_id=user.id,
                branch_id='branch-1',
                customer_name='Parent',
                phone='+77000000000',
                child_id=child.id,
                requested_date=date(2026, 9, 20),
                status='completed',
            ))
            session.commit()
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            reminder = session.query(BirthdayReminder).one()
            self.assertEqual(reminder.skip_reason, 'active_lead')
            self.assertEqual(len(delivery.tokens), 0)

    def test_cancelled_lead_allows_but_confirmed_lead_suppresses(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            user, child = self._user(session, birth_date=date(2020, 9, 20))
            session.add(BirthdayRequest(
                id=uuid4().hex,
                mobile_user_id=user.id,
                branch_id='branch-1',
                customer_name='Parent',
                phone='+77000000000',
                child_id=child.id,
                status='cancelled',
            ))
            session.commit()
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            self.assertEqual(session.query(BirthdayReminder).one().status, 'sent')
            self.assertEqual(len(delivery.tokens), 1)

        with self.SessionLocal() as session:
            user, child = self._user(session, birth_date=date(2020, 9, 20))
            session.add(BirthdayRequest(
                id=uuid4().hex,
                mobile_user_id=user.id,
                branch_id='branch-1',
                customer_name='Parent',
                phone='+77000000000',
                child_id=child.id,
                status='confirmed',
            ))
            session.commit()
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            self.assertEqual(
                session.query(BirthdayReminder).filter_by(child_id=child.id).one().skip_reason,
                'active_lead',
            )

    def test_lead_created_after_fourteen_day_reminder_suppresses_seven_day_window(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            user, child = self._user(session, birth_date=date(2020, 9, 20))
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            session.add(BirthdayRequest(
                id=uuid4().hex,
                mobile_user_id=user.id,
                branch_id='branch-1',
                customer_name='Parent',
                phone='+77000000000',
                child_id=child.id,
                status='new',
            ))
            session.commit()
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='7')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 13, 12, tzinfo=UTC))
            seven_day = session.query(BirthdayReminder).filter_by(days_before=7).one()
            self.assertEqual(seven_day.skip_reason, 'active_lead')
            self.assertEqual(len(delivery.tokens), 1)

    def test_feature_off_is_noop_and_no_campaign(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            self._user(session, birth_date=date(2020, 9, 20))
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(enabled=False)):
                self.assertEqual(service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC)), 0)
            self.assertEqual(session.query(BirthdayReminder).count(), 0)
            self.assertEqual(session.query(PushCampaign).count(), 0)

    def test_provider_off_never_marks_reminder_sent(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            self._user(session, birth_date=date(2020, 9, 20))
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=False):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            reminder = session.query(BirthdayReminder).one()
            self.assertEqual(reminder.status, 'pending')
            self.assertEqual(session.query(PushCampaign).count(), 0)
            self.assertEqual(len(delivery.tokens), 0)

    def test_no_device_is_skipped_without_campaign(self) -> None:
        delivery = FakeDelivery()
        with self.SessionLocal() as session:
            self._user(session, birth_date=date(2020, 9, 20), devices=0)
            service = self._service(session, delivery)
            with patch('app.modules.birthday_reminders.service.get_settings', return_value=self._settings(windows='14')), \
                 patch.object(PushCampaignService, 'provider_configured', new_callable=PropertyMock, return_value=True):
                service.process(now=datetime(2026, 9, 6, 12, tzinfo=UTC))
            reminder = session.query(BirthdayReminder).one()
            self.assertEqual((reminder.status, reminder.skip_reason), ('skipped', 'no_active_device'))
            self.assertEqual(session.query(PushCampaign).count(), 0)
