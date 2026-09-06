from __future__ import annotations

from datetime import date, timedelta
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.birthday_package import BirthdayPackage
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.branch import Branch
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.main import app


class BirthdayLeadV2EndpointTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            'sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool
        )
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
            session.query(BirthdayRequest).delete()
            session.query(MobileChild).delete()
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.query(BirthdayPackage).delete()
            session.query(Branch).delete()
            session.add(
                Branch(
                    id='branch-main', slug='branch-main', name='Boom Bala Main', city='Almaty',
                    address='Abay', short_label='Main', working_hours='10:00 - 22:00',
                    description='Main', phone='+77070000000', whatsapp_phone='+77070000000',
                    hero_image_url=None, gallery_image_urls=[], facilities=[], display_order=1,
                    is_active=True,
                )
            )
            session.add(
                BirthdayPackage(
                    id='package-main', branch_id='branch-main', slug='package-main',
                    name='Spark Party', price_from=55000, price_label='от 55 000 ₸',
                    guest_capacity_label='до 10 детей', description='Party', highlights=[],
                    image_url=None, is_featured=False, is_active=True, display_order=1,
                )
            )
            session.commit()

    def _auth(self, email: str = 'lead-v2@example.com') -> tuple[dict, str]:
        response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={'email': email, 'password': 'Pass123456'},
        )
        self.assertEqual(response.status_code, 200, response.text)
        body = response.json()
        return body, f"Bearer {body['access_token']}"

    def _create_child(self, headers: dict[str, str]) -> str:
        response = self.client.post(
            '/api/v1/mobile/me/children',
            headers=headers,
            json={'name': 'Алина', 'birthDate': '2020-09-15', 'gender': 'female'},
        )
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()['id']

    def _payload(self, child_id: str, key: str = 'lead-v2-request-1') -> dict[str, object]:
        return {
            'name': 'Айжан',
            'phone': '+77071234567',
            'branchId': 'branch-main',
            'packageId': 'package-main',
            'childId': child_id,
            'preferredDate': str(date.today() + timedelta(days=7)),
            'guestCount': 12,
            'comment': 'Нужен аниматор',
            'idempotencyKey': key,
        }

    def test_authenticated_lead_persists_structured_child_and_package_snapshot(self) -> None:
        _, token = self._auth()
        headers = {'Authorization': token}
        child_id = self._create_child(headers)

        response = self.client.post('/api/v1/mobile/leads/birthday', headers=headers, json=self._payload(child_id))

        self.assertEqual(response.status_code, 201, response.text)
        lead_id = response.json()['requestId']
        with self.SessionLocal() as session:
            request = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == lead_id))
            self.assertEqual(request.child_id, child_id)
            self.assertEqual(request.child_name_snapshot, 'Алина')
            self.assertEqual(request.package_name_snapshot, 'Spark Party')
            self.assertEqual(request.package_price_snapshot, 55000)

    def test_same_idempotency_key_returns_one_lead(self) -> None:
        _, token = self._auth('idempotent@example.com')
        headers = {'Authorization': token}
        child_id = self._create_child(headers)
        payload = self._payload(child_id)

        first = self.client.post('/api/v1/mobile/leads/birthday', headers=headers, json=payload)
        retry = self.client.post('/api/v1/mobile/leads/birthday', headers=headers, json=payload)

        self.assertEqual(first.status_code, 201, first.text)
        self.assertEqual(retry.status_code, 201, retry.text)
        self.assertEqual(first.json()['requestId'], retry.json()['requestId'])
        with self.SessionLocal() as session:
            self.assertEqual(session.query(BirthdayRequest).count(), 1)

    def test_foreign_child_is_rejected_and_user_only_reads_own_leads(self) -> None:
        _, first_token = self._auth('first@example.com')
        first_headers = {'Authorization': first_token}
        first_child_id = self._create_child(first_headers)
        _, second_token = self._auth('second@example.com')
        second_headers = {'Authorization': second_token}

        rejected = self.client.post(
            '/api/v1/mobile/leads/birthday', headers=second_headers,
            json=self._payload(first_child_id, key='foreign-child'),
        )
        self.assertIn(rejected.status_code, {403, 404})
        self.assertEqual(self.client.get('/api/v1/mobile/leads/birthday', headers=second_headers).json()['total'], 0)

    def test_authenticated_lead_requires_child_and_date(self) -> None:
        _, token = self._auth('required-fields@example.com')
        headers = {'Authorization': token}
        response = self.client.post(
            '/api/v1/mobile/leads/birthday', headers=headers,
            json={
                'name': 'Айжан', 'phone': '+77071234567',
                'branchId': 'branch-main', 'packageId': 'package-main',
                'guestCount': 10, 'idempotencyKey': 'required-fields',
            },
        )
        self.assertEqual(response.status_code, 422)

