from __future__ import annotations

from datetime import UTC, date, datetime
import unittest

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.exceptions.http import DomainHTTPException
from app.db.models import Base
from app.db.models.birthday_reminder import BirthdayReminder
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.birthday_revenue_cycle import BirthdayRevenueCycle
from app.db.models.branch import Branch
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_user import MobileUser
from app.db.models.push_campaign import PushCampaign
from app.db.repositories.branch_repository import BranchRepository
from app.db.repositories.birthday_package_repository import BirthdayPackageRepository
from app.db.repositories.lead_repository import LeadRepository
from app.db.repositories.mobile_child_repository import MobileChildRepository
from app.modules.birthday_reminders.revenue_service import BirthdayRevenueReportService
from app.modules.leads.schemas import BirthdayLeadCreate
from app.modules.leads.service import LeadService


class BirthdayRevenueReportTests(unittest.TestCase):
    def test_rates_use_unique_cycles_when_multiple_leads_exist(self) -> None:
        cycle = BirthdayRevenueCycle(
            id='cycle-one',
            mobile_user_id='user-one',
            birthday_year=2026,
            target_date=date(2026, 10, 6),
            experiment_group='treatment',
            eligible_at=datetime(2026, 9, 6, tzinfo=UTC),
        )
        first = BirthdayRequest(
            id='lead-one',
            birthday_cycle_id=cycle.id,
            status='new',
        )
        second = BirthdayRequest(
            id='lead-two',
            birthday_cycle_id=cycle.id,
            status='paid',
            paid_amount_tenge=50_000,
            paid_at=datetime(2026, 9, 10, tzinfo=UTC),
        )

        summary = BirthdayRevenueReportService._summary(
            BirthdayRevenueReportService.__new__(BirthdayRevenueReportService),
            [cycle],
            {cycle.id: [first, second]},
        )

        self.assertEqual(summary['leads'], 2)
        self.assertEqual(summary['lead_rate'], 1.0)
        self.assertEqual(summary['paid_rate'], 1.0)


class BirthdayLeadCampaignAttributionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            'sqlite://',
            connect_args={'check_same_thread': False},
            poolclass=StaticPool,
        )
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)

    @classmethod
    def tearDownClass(cls) -> None:
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            for model in (
                BirthdayRequest,
                BirthdayReminder,
                PushCampaign,
                BirthdayRevenueCycle,
                MobileChild,
                MobileUser,
                Branch,
            ):
                session.query(model).delete()
            session.add(
                Branch(
                    id='branch-main',
                    slug='branch-main',
                    name='Boom Bala Main',
                    city='Almaty',
                    address='Abay',
                    short_label='Main',
                    working_hours='10:00 - 22:00',
                    description='Main',
                    phone='+77070000000',
                    whatsapp_phone='+77070000000',
                    gallery_image_urls=[],
                    facilities=[],
                    display_order=1,
                    is_active=True,
                )
            )
            user = MobileUser(id='user-one', phone='+77070000001', is_active=True)
            session.add(user)
            session.add_all([
                MobileChild(
                    id='child-valid', user_id=user.id, name='Алина',
                    birth_date=date(2020, 10, 6), gender='female',
                ),
                MobileChild(
                    id='child-wrong-date', user_id=user.id, name='Али',
                    birth_date=date(2020, 11, 6), gender='male',
                ),
            ])
            cycle = BirthdayRevenueCycle(
                id='cycle-one', mobile_user_id=user.id, birthday_year=2026,
                target_date=date(2026, 10, 6), experiment_group='treatment',
                eligible_at=datetime(2026, 9, 6, tzinfo=UTC),
            )
            campaign = PushCampaign(
                id='campaign-one',
                internal_name='birthday-revenue-test',
                title='title',
                body='body',
                audience_type='user',
                audience_config={'user_id': user.id},
                destination='birthdays',
                destination_payload={
                    'birthdayCycleId': cycle.id,
                    'birthdayChildId': 'child-valid',
                    'preferredDate': '2026-10-06',
                },
                status='sent',
                origin='system_birthday',
            )
            session.add_all([cycle, campaign])
            session.flush()
            session.add(
                BirthdayReminder(
                    child_id='child-valid',
                    mobile_user_id=user.id,
                    birthday_year=2026,
                    days_before=30,
                    birthday_cycle_id=cycle.id,
                    push_campaign_id=campaign.id,
                    status='sent',
                )
            )
            session.commit()

    def _service(self, session: Session) -> LeadService:
        return LeadService(
            repository=LeadRepository(session),
            branch_repository=BranchRepository(session),
            package_repository=BirthdayPackageRepository(session),
            child_repository=MobileChildRepository(session),
        )

    def _payload(self, *, child_id: str | None, key: str, cycle_id: str = 'cycle-one') -> BirthdayLeadCreate:
        return BirthdayLeadCreate(
            name='Айжан',
            phone='+77071234567',
            branchId='branch-main',
            preferredDate=date(2026, 10, 6),
            guestCount=10,
            childId=child_id,
            sourceCampaignId='campaign-one',
            birthdayCycleId=cycle_id,
            idempotencyKey=key,
        )

    def test_valid_child_keeps_cycle_attribution(self) -> None:
        with self.SessionLocal() as session:
            result = self._service(session).create_birthday_lead(
                self._payload(child_id='child-valid', key='valid-cycle-key'),
                mobile_user_id='user-one',
            )
            saved = session.get(BirthdayRequest, result.requestId)
            self.assertEqual(saved.birthday_cycle_id, 'cycle-one')
            self.assertEqual(saved.source_campaign_id, 'campaign-one')
            self.assertEqual(saved.source, 'birthday_crm')

    def test_wrong_child_keeps_campaign_source_but_degrades_cycle_attribution(self) -> None:
        with self.SessionLocal() as session:
            result = self._service(session).create_birthday_lead(
                self._payload(child_id='child-wrong-date', key='wrong-child-key'),
                mobile_user_id='user-one',
            )
            saved = session.get(BirthdayRequest, result.requestId)
            self.assertIsNone(saved.birthday_cycle_id)
            self.assertEqual(saved.source_campaign_id, 'campaign-one')
            self.assertEqual(saved.source, 'birthday_crm')

    def test_wrong_user_campaign_is_rejected(self) -> None:
        with self.SessionLocal() as session:
            with self.assertRaises(DomainHTTPException) as raised:
                self._service(session).create_birthday_lead(
                    self._payload(child_id='child-valid', key='wrong-user-key'),
                    mobile_user_id='user-two',
                )
            self.assertEqual(raised.exception.code, 'invalid_birthday_campaign')

    def test_manual_campaign_is_rejected(self) -> None:
        with self.SessionLocal() as session:
            session.get(PushCampaign, 'campaign-one').origin = 'manual'
            session.commit()
            with self.assertRaises(DomainHTTPException) as raised:
                self._service(session).create_birthday_lead(
                    self._payload(child_id='child-valid', key='manual-campaign-key'),
                    mobile_user_id='user-one',
                )
            self.assertEqual(raised.exception.code, 'invalid_birthday_campaign')

    def test_campaign_cycle_mismatch_is_rejected(self) -> None:
        with self.SessionLocal() as session:
            session.add(
                BirthdayRevenueCycle(
                    id='cycle-two', mobile_user_id='user-one', birthday_year=2026,
                    target_date=date(2026, 11, 6), experiment_group='treatment',
                    eligible_at=datetime(2026, 9, 6, tzinfo=UTC),
                )
            )
            session.commit()
            with self.assertRaises(DomainHTTPException) as raised:
                self._service(session).create_birthday_lead(
                    self._payload(child_id='child-valid', key='mismatch-key', cycle_id='cycle-two'),
                    mobile_user_id='user-one',
                )
            self.assertEqual(raised.exception.code, 'invalid_birthday_campaign')

