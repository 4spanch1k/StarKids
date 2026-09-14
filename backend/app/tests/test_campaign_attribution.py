from __future__ import annotations

import unittest
from datetime import UTC, date, datetime, timedelta
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.exceptions.http import DomainHTTPException
from app.db.models import Base
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.models.push_campaign import PushCampaign
from app.db.models.push_campaign_delivery import PushCampaignDelivery
from app.db.models.push_campaign_open import PushCampaignOpen
from app.db.models.visit import Visit
from app.main import app
from app.modules.admin_push_campaigns.attribution_service import PushCampaignAttributionService


class CampaignAttributionServiceTests(unittest.TestCase):
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
            session.query(BirthdayRequest).delete()
            session.query(Visit).delete()
            session.query(PushCampaignOpen).delete()
            session.query(PushCampaignDelivery).delete()
            session.query(PushCampaign).delete()
            session.commit()

    def _campaign(self, session: Session, *, targeted_users: int = 1) -> PushCampaign:
        campaign = PushCampaign(
            id=uuid4().hex,
            internal_name='campaign',
            title='title',
            body='body',
            audience_type='all_users',
            audience_config={},
            destination='home',
            destination_payload={},
            status='sent',
            targeted_users=targeted_users,
        )
        session.add(campaign)
        session.flush()
        return campaign

    def _delivery(self, session: Session, campaign: PushCampaign, user_id: str, *, status: str = 'sent', device_suffix: str = '') -> None:
        session.add(PushCampaignDelivery(
            id=uuid4().hex,
            campaign_id=campaign.id,
            mobile_user_id=user_id,
            device_id=f'device-{user_id}-{device_suffix or uuid4().hex}',
            token_snapshot=f'token-{user_id}',
            status=status,
        ))

    def test_open_is_authenticated_delivery_bound_and_idempotent(self) -> None:
        with self.SessionLocal() as session:
            campaign = self._campaign(session)
            user_id = uuid4().hex
            self._delivery(session, campaign, user_id)
            session.commit()
            service = PushCampaignAttributionService(session)
            opened_at = datetime(2026, 9, 8, 10, tzinfo=UTC)
            service.record_open(campaign.id, user_id, opened_at=opened_at)
            service.record_open(campaign.id, user_id, opened_at=opened_at + timedelta(hours=1))
            row = session.query(PushCampaignOpen).one()
            self.assertEqual(row.opened_at.replace(tzinfo=UTC), opened_at)

            with self.assertRaises(DomainHTTPException):
                service.record_open(campaign.id, uuid4().hex)
            with self.assertRaises(DomainHTTPException):
                service.record_open(uuid4().hex, user_id)

    def test_report_counts_sent_users_not_devices_and_last_touch_outcomes(self) -> None:
        now = datetime(2026, 9, 8, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            campaign_a = self._campaign(session, targeted_users=2)
            campaign_b = self._campaign(session, targeted_users=1)
            user_one = uuid4().hex
            user_two = uuid4().hex
            self._delivery(session, campaign_a, user_one, device_suffix='one')
            self._delivery(session, campaign_a, user_one, device_suffix='two')
            self._delivery(session, campaign_a, user_two)
            self._delivery(session, campaign_b, user_one)
            session.add_all([
                PushCampaignOpen(id=uuid4().hex, campaign_id=campaign_a.id, mobile_user_id=user_one, opened_at=now - timedelta(days=7) + timedelta(hours=1)),
                PushCampaignOpen(id=uuid4().hex, campaign_id=campaign_b.id, mobile_user_id=user_one, opened_at=now - timedelta(days=4)),
                PushCampaignOpen(id=uuid4().hex, campaign_id=campaign_a.id, mobile_user_id=user_two, opened_at=now - timedelta(days=2)),
                Visit(id=uuid4().hex, mobile_payment_id=uuid4().hex, mobile_user_id=user_one, branch_id=uuid4().hex, status='completed', started_at=now - timedelta(days=3)),
                Visit(id=uuid4().hex, mobile_payment_id=uuid4().hex, mobile_user_id=user_one, branch_id=uuid4().hex, status='completed', started_at=now - timedelta(days=2)),
                Visit(id=uuid4().hex, mobile_payment_id=uuid4().hex, mobile_user_id=user_two, branch_id=uuid4().hex, status='completed', started_at=now + timedelta(days=8)),
                BirthdayRequest(id=uuid4().hex, mobile_user_id=user_one, branch_id=uuid4().hex, customer_name='A', phone='+70000000001', created_at=now - timedelta(days=3), status='new'),
                BirthdayRequest(id=uuid4().hex, mobile_user_id=user_two, branch_id=uuid4().hex, customer_name='B', phone='+70000000002', created_at=now - timedelta(days=1), status='new'),
            ])
            session.commit()
            report = PushCampaignAttributionService(session).report(campaign_a.id)

            self.assertEqual(report.targeted_users, 2)
            self.assertEqual(report.sent_users, 2)
            self.assertEqual(report.opened_users, 2)
            self.assertEqual(report.open_rate, 1.0)
            # User one's two outcomes are last-touch attributed to campaign B.
            self.assertEqual(report.attributed_visit_users, 0)
            self.assertEqual(report.attributed_visits, 0)
            self.assertEqual(report.attributed_birthday_leads, 1)
            self.assertEqual(report.attributed_birthday_lead_users, 1)

            report_b = PushCampaignAttributionService(session).report(campaign_b.id)
            self.assertEqual(report_b.attributed_visit_users, 1)
            self.assertEqual(report_b.attributed_visits, 2)
            self.assertEqual(report_b.attributed_birthday_leads, 1)

    def test_attribution_window_is_seven_days_exclusive_and_outcomes_before_open_are_ignored(self) -> None:
        now = datetime(2026, 9, 8, 12, tzinfo=UTC)
        with self.SessionLocal() as session:
            campaign = self._campaign(session)
            user_id = uuid4().hex
            self._delivery(session, campaign, user_id)
            session.add(PushCampaignOpen(id=uuid4().hex, campaign_id=campaign.id, mobile_user_id=user_id, opened_at=now))
            session.add_all([
                Visit(id=uuid4().hex, mobile_payment_id=uuid4().hex, mobile_user_id=user_id, branch_id=uuid4().hex, status='completed', started_at=now - timedelta(minutes=1)),
                Visit(id=uuid4().hex, mobile_payment_id=uuid4().hex, mobile_user_id=user_id, branch_id=uuid4().hex, status='completed', started_at=now + timedelta(days=7)),
                Visit(id=uuid4().hex, mobile_payment_id=uuid4().hex, mobile_user_id=user_id, branch_id=uuid4().hex, status='completed', started_at=now + timedelta(days=6, hours=23)),
            ])
            session.commit()
            report = PushCampaignAttributionService(session).report(campaign.id)
            self.assertEqual(report.attributed_visits, 1)


class CampaignOpenEndpointTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine('sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)

        def override_get_db_session():
            session = cls.SessionLocal()
            try:
                yield session
            finally:
                session.close()

        app.dependency_overrides[get_db_session] = override_get_db_session
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(PushCampaignOpen).delete()
            session.query(PushCampaignDelivery).delete()
            session.query(PushCampaign).delete()
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.commit()

    def test_authenticated_recipient_can_open_once_and_unrelated_user_is_rejected(self) -> None:
        self.assertEqual(
            self.client.post(f'/api/v1/mobile/push-campaigns/{uuid4().hex}/open').status_code,
            401,
        )
        auth = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={'phone': '+77071234567', 'code': '1234', 'verification_id': 'otp_endpoint'},
        )
        self.assertEqual(auth.status_code, 200)
        user_id = auth.json()['user']['id']
        with self.SessionLocal() as session:
            campaign = PushCampaign(
                id=uuid4().hex,
                internal_name='endpoint', title='t', body='b', audience_type='all_users',
                audience_config={}, destination='home', destination_payload={}, status='sent',
            )
            session.add(campaign)
            session.add(PushCampaignDelivery(
                id=uuid4().hex, campaign_id=campaign.id, mobile_user_id=user_id,
                device_id='device-endpoint', token_snapshot='token', status='sent',
            ))
            session.commit()
            campaign_id = campaign.id

        headers = {'Authorization': f"Bearer {auth.json()['access_token']}"}
        first = self.client.post(f'/api/v1/mobile/push-campaigns/{campaign_id}/open', headers=headers)
        second = self.client.post(f'/api/v1/mobile/push-campaigns/{campaign_id}/open', headers=headers)
        self.assertEqual(first.status_code, 204)
        self.assertEqual(second.status_code, 204)
        with self.SessionLocal() as session:
            self.assertEqual(session.query(PushCampaignOpen).filter_by(campaign_id=campaign_id).count(), 1)

        random_campaign = self.client.post(
            f'/api/v1/mobile/push-campaigns/{uuid4().hex}/open', headers=headers,
        )
        self.assertEqual(random_campaign.status_code, 404)


if __name__ == '__main__':
    unittest.main()
