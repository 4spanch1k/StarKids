from __future__ import annotations

from datetime import UTC, date, datetime
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.security.passwords import hash_password
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.branch import Branch
from app.main import app


class BirthdaySalesFunnelV3Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            'sqlite://',
            connect_args={'check_same_thread': False},
            poolclass=StaticPool,
        )
        cls.SessionLocal = sessionmaker(
            bind=cls.engine,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
            class_=Session,
        )

        def override_get_db_session():
            session = cls.SessionLocal()
            try:
                yield session
            finally:
                session.close()

        Base.metadata.create_all(cls.engine)
        app.dependency_overrides[get_db_session] = override_get_db_session
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(AdminSession).delete()
            session.query(BirthdayRequest).delete()
            session.query(AdminUser).delete()
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
            session.add(
                AdminUser(
                    id='admin-super',
                    email='admin@example.com',
                    full_name='Platform Admin',
                    password_hash=hash_password('StrongPass123!'),
                    role='super_admin',
                    is_active=True,
                )
            )
            session.add(
                BirthdayRequest(
                    id='lead-v3',
                    branch_id='branch-main',
                    customer_name='Amina',
                    phone='+77070000000',
                    child_name_snapshot='Aлина',
                    requested_date=date(2026, 10, 10),
                    guest_count=10,
                    contact_method='phone',
                    source='mobile_app',
                    status='new',
                    created_at=datetime(2026, 9, 8, 8, 0, tzinfo=UTC),
                )
            )
            session.commit()

    def test_target_status_flow_sets_first_touch_timestamps_and_agreed_amount(self) -> None:
        headers = self._auth_headers()

        for status, expected_field in (
            ('contacted', 'contacted_at'),
            ('qualified', 'qualified_at'),
            ('booked', 'booked_at'),
        ):
            response = self.client.patch(
                '/api/v1/admin/leads/lead-v3/status',
                headers=headers,
                json={'status': status},
            )
            self.assertEqual(response.status_code, 200, response.text)
            with self.SessionLocal() as session:
                lead = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == 'lead-v3'))
                self.assertEqual(lead.status, status)
                self.assertIsNotNone(getattr(lead, expected_field))

        response = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'completed', 'agreedAmountTenge': 180000},
        )
        self.assertEqual(response.status_code, 200, response.text)
        with self.SessionLocal() as session:
            lead = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == 'lead-v3'))
            self.assertEqual(lead.status, 'completed')
            self.assertEqual(lead.agreed_amount_tenge, 180000)
            self.assertIsNotNone(lead.completed_at)
            self.assertIsNotNone(lead.closed_at)

    def test_lost_requires_structured_reason_and_accepts_non_negative_amount(self) -> None:
        headers = self._auth_headers()

        missing_reason = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'lost'},
        )
        self.assertEqual(missing_reason.status_code, 422)
        self.assertEqual(missing_reason.json()['error']['code'], 'lost_reason_required')

        invalid_reason = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'lost', 'lostReason': 'made_up'},
        )
        self.assertEqual(invalid_reason.status_code, 422)

        valid = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={
                'status': 'lost',
                'lostReason': 'too_expensive',
                'agreedAmountTenge': 0,
            },
        )
        self.assertEqual(valid.status_code, 200, valid.text)
        with self.SessionLocal() as session:
            lead = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == 'lead-v3'))
            self.assertEqual(lead.status, 'lost')
            self.assertEqual(lead.lost_reason, 'too_expensive')
            self.assertEqual(lead.agreed_amount_tenge, 0)
            self.assertIsNotNone(lead.lost_at)
            self.assertIsNotNone(lead.closed_at)

    def test_completed_lead_cannot_regress_and_repeated_status_keeps_first_timestamp(self) -> None:
        headers = self._auth_headers()
        contacted = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'contacted'},
        )
        self.assertEqual(contacted.status_code, 200, contacted.text)
        with self.SessionLocal() as session:
            first_contacted_at = session.scalar(
                select(BirthdayRequest.contacted_at).where(BirthdayRequest.id == 'lead-v3')
            )

        repeated = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'contacted'},
        )
        self.assertEqual(repeated.status_code, 200, repeated.text)
        with self.SessionLocal() as session:
            self.assertEqual(
                session.scalar(select(BirthdayRequest.contacted_at).where(BirthdayRequest.id == 'lead-v3')),
                first_contacted_at,
            )

        for status in ('qualified', 'booked', 'completed'):
            response = self.client.patch(
                '/api/v1/admin/leads/lead-v3/status',
                headers=headers,
                json={'status': status},
            )
            self.assertEqual(response.status_code, 200, response.text)

        regress = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'new'},
        )
        self.assertEqual(regress.status_code, 422)
        self.assertEqual(regress.json()['error']['code'], 'invalid_lead_status_transition')

    def test_paid_stage_records_received_money_and_paid_timestamp(self) -> None:
        headers = self._auth_headers()
        for status, payload in (
            ('contacted', {}),
            ('qualified', {'expectedAmountTenge': 220000}),
            ('booked', {'expectedAmountTenge': 220000}),
            ('paid', {'expectedAmountTenge': 220000, 'depositAmountTenge': 50000, 'paidAmountTenge': 50000}),
        ):
            response = self.client.patch(
                '/api/v1/admin/leads/lead-v3/status',
                headers=headers,
                json={'status': status, **payload},
            )
            self.assertEqual(response.status_code, 200, response.text)

        with self.SessionLocal() as session:
            lead = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == 'lead-v3'))
            self.assertEqual(lead.status, 'paid')
            self.assertEqual(lead.expected_amount_tenge, 220000)
            self.assertEqual(lead.agreed_amount_tenge, 220000)
            self.assertEqual(lead.deposit_amount_tenge, 50000)
            self.assertEqual(lead.paid_amount_tenge, 50000)
            self.assertIsNotNone(lead.paid_at)

        detail = self.client.get(
            '/api/v1/admin/leads/lead-v3/birthday',
            headers=headers,
        )
        self.assertEqual(detail.status_code, 200, detail.text)
        self.assertEqual(detail.json()['expectedAmountTenge'], 220000)
        self.assertEqual(detail.json()['depositAmountTenge'], 50000)
        self.assertEqual(detail.json()['paidAmountTenge'], 50000)

        completed = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'completed'},
        )
        self.assertEqual(completed.status_code, 200, completed.text)

    def test_partial_payment_is_valid_before_and_at_manual_paid_stage(self) -> None:
        headers = self._auth_headers()
        for status in ('contacted', 'qualified'):
            response = self.client.patch(
                '/api/v1/admin/leads/lead-v3/status',
                headers=headers,
                json={'status': status},
            )
            self.assertEqual(response.status_code, 200, response.text)

        booked = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={
                'status': 'booked',
                'expectedAmountTenge': 200000,
                'depositAmountTenge': 50000,
                'paidAmountTenge': 50000,
            },
        )
        self.assertEqual(booked.status_code, 200, booked.text)

        partial_paid = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={
                'status': 'paid',
                'expectedAmountTenge': 200000,
                'depositAmountTenge': 50000,
                'paidAmountTenge': 50000,
            },
        )
        self.assertEqual(partial_paid.status_code, 200, partial_paid.text)

        full_paid = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={
                'status': 'paid',
                'expectedAmountTenge': 200000,
                'depositAmountTenge': 50000,
                'paidAmountTenge': 200000,
            },
        )
        self.assertEqual(full_paid.status_code, 200, full_paid.text)

        with self.SessionLocal() as session:
            lead = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == 'lead-v3'))
            self.assertEqual(lead.status, 'paid')
            self.assertEqual(lead.expected_amount_tenge, 200000)
            self.assertEqual(lead.deposit_amount_tenge, 50000)
            self.assertEqual(lead.paid_amount_tenge, 200000)
            self.assertIsNotNone(lead.paid_at)

        completed = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'completed'},
        )
        self.assertEqual(completed.status_code, 200, completed.text)
        with self.SessionLocal() as session:
            lead = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == 'lead-v3'))
            self.assertEqual(lead.status, 'completed')
            self.assertEqual(lead.paid_amount_tenge, 200000)

    def test_paid_requires_received_amount_and_deposit_cannot_exceed_paid(self) -> None:
        headers = self._auth_headers()
        for status in ('contacted', 'qualified', 'booked'):
            response = self.client.patch(
                '/api/v1/admin/leads/lead-v3/status',
                headers=headers,
                json={'status': status},
            )
            self.assertEqual(response.status_code, 200, response.text)

        missing_paid = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'paid'},
        )
        self.assertEqual(missing_paid.status_code, 422)
        self.assertEqual(missing_paid.json()['error']['code'], 'paid_amount_required')

        invalid_ratio = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'paid', 'depositAmountTenge': 50000, 'paidAmountTenge': 10000},
        )
        self.assertEqual(invalid_ratio.status_code, 422)
        self.assertEqual(invalid_ratio.json()['error']['code'], 'deposit_exceeds_paid_amount')

    def test_lost_lead_can_be_reopened_without_current_loss_reason(self) -> None:
        headers = self._auth_headers()
        lost = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'lost', 'lostReason': 'duplicate'},
        )
        self.assertEqual(lost.status_code, 200, lost.text)

        reopened = self.client.patch(
            '/api/v1/admin/leads/lead-v3/status',
            headers=headers,
            json={'status': 'contacted'},
        )
        self.assertEqual(reopened.status_code, 200, reopened.text)
        with self.SessionLocal() as session:
            lead = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == 'lead-v3'))
            self.assertEqual(lead.status, 'contacted')
            self.assertIsNone(lead.lost_reason)
            self.assertIsNotNone(lead.lost_at)

    def _auth_headers(self) -> dict[str, str]:
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={'email': 'admin@example.com', 'password': 'StrongPass123!'},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}
