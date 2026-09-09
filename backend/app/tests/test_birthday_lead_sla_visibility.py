from __future__ import annotations

from datetime import UTC, date, datetime
import unittest

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.models import Base
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.branch import Branch
from app.db.models.contact_lead import ContactLead
from app.db.repositories.lead_inbox_repository import LeadInboxRepository
from app.modules.admin_dashboard.schemas import OwnerDashboardPeriod
from app.modules.admin_leads.schemas import AdminLeadListQuery
from app.modules.admin_leads.service import AdminLeadInboxService


class BirthdayLeadSlaVisibilityTests(unittest.TestCase):
    NOW = datetime(2026, 9, 8, 10, 0, tzinfo=UTC)

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
            session.query(BirthdayRequest).delete()
            session.query(ContactLead).delete()
            session.query(Branch).delete()
            session.add(
                Branch(
                    id='branch-main',
                    slug='main',
                    name='Boom Bala Main',
                    city='Almaty',
                    address='Abay 1',
                    short_label='Main',
                    working_hours='10:00-22:00',
                    description='Main',
                    phone='+77070000000',
                    whatsapp_phone='+77070000000',
                    hero_image_url=None,
                    gallery_image_urls=[],
                    facilities=[],
                    display_order=1,
                    is_active=True,
                )
            )
            session.add_all(
                [
                    self._lead('waiting-old', 'new', self.NOW.replace(hour=9, minute=50)),
                    self._lead('waiting-new', 'new', self.NOW.replace(hour=9, minute=55)),
                    self._lead(
                        'contacted',
                        'contacted',
                        self.NOW.replace(hour=8, minute=0),
                        contacted_at=self.NOW.replace(hour=8, minute=18),
                    ),
                    self._lead(
                        'contacted-20',
                        'contacted',
                        self.NOW.replace(hour=7, minute=0),
                        contacted_at=self.NOW.replace(hour=7, minute=20),
                    ),
                    self._lead(
                        'contacted-30',
                        'contacted',
                        self.NOW.replace(hour=6, minute=0),
                        contacted_at=self.NOW.replace(hour=6, minute=30),
                    ),
                    self._lead(
                        'completed-legacy',
                        'completed',
                        self.NOW.replace(hour=5, minute=0),
                    ),
                ]
            )
            session.add(
                ContactLead(
                    id='contact-lead',
                    customer_name='Contact only',
                    phone='+77070000001',
                    email=None,
                    message='General question',
                    status='new',
                    created_at=self.NOW.replace(hour=9, minute=40),
                )
            )
            session.commit()

    def _lead(
        self,
        lead_id: str,
        status: str,
        created_at: datetime,
        *,
        contacted_at: datetime | None = None,
    ) -> BirthdayRequest:
        return BirthdayRequest(
            id=lead_id,
            branch_id='branch-main',
            customer_name=lead_id,
            phone='+77070000000',
            child_name_snapshot='Child',
            requested_date=date(2026, 10, 1),
            contact_method='phone',
            source='mobile_app',
            status=status,
            created_at=created_at,
            contacted_at=contacted_at,
        )

    def _service(self, session: Session) -> AdminLeadInboxService:
        return AdminLeadInboxService(
            repository=LeadInboxRepository(session),
            now_provider=lambda: self.NOW,
        )

    def test_waiting_and_first_contact_minutes_are_derived_from_timestamps(self) -> None:
        with self.SessionLocal() as session:
            service = self._service(session)
            records = service.list_leads(AdminLeadListQuery())
            by_id = {item.id: item for item in records.items}

        self.assertEqual(by_id['waiting-old'].waitingForContactMinutes, 10)
        self.assertIsNone(by_id['waiting-old'].firstContactMinutes)
        self.assertIsNone(by_id['contacted'].waitingForContactMinutes)
        self.assertEqual(by_id['contacted'].firstContactMinutes, 18)
        self.assertIsNone(by_id['completed-legacy'].waitingForContactMinutes)
        self.assertIsNone(by_id['completed-legacy'].firstContactMinutes)

    def test_awaiting_filter_and_oldest_sort_only_use_new_uncontacted_birthdays(self) -> None:
        with self.SessionLocal() as session:
            service = self._service(session)
            filtered = service.list_leads(AdminLeadListQuery(awaitingContact=True))
            sorted_records = service.list_leads(
                AdminLeadListQuery(sort='oldest_uncontacted')
            )

        self.assertEqual({item.id for item in filtered.items}, {'waiting-old', 'waiting-new'})
        self.assertNotIn('contact-lead', {item.id for item in filtered.items})
        self.assertEqual(
            [item.id for item in sorted_records.items[:2]],
            ['waiting-old', 'waiting-new'],
        )

    def test_operations_summary_has_current_queue_and_period_response_metrics(self) -> None:
        with self.SessionLocal() as session:
            summary = self._service(session).get_birthday_operations_summary(
                OwnerDashboardPeriod.TODAY
            )

        self.assertEqual(summary.newAwaitingContact, 2)
        self.assertEqual(summary.oldestWaitingMinutes, 10)
        self.assertEqual(summary.leadsCreated, 6)
        self.assertEqual(summary.contactedFromCreatedLeads, 3)
        self.assertEqual(summary.medianFirstContactMinutes, 20)
        self.assertEqual(summary.p90FirstContactMinutes, 30)

    def test_empty_contact_sample_returns_null_percentile_metrics(self) -> None:
        with self.SessionLocal() as session:
            session.query(BirthdayRequest).filter(BirthdayRequest.contacted_at.is_not(None)).delete()
            session.commit()
            summary = self._service(session).get_birthday_operations_summary(
                OwnerDashboardPeriod.TODAY
            )

        self.assertIsNone(summary.medianFirstContactMinutes)
        self.assertIsNone(summary.p90FirstContactMinutes)
