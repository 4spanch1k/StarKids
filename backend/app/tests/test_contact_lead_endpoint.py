from datetime import UTC, datetime
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
from app.db.models.contact_lead import ContactLead
from app.main import app


class ContactLeadEndpointTests(unittest.TestCase):
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
            session.query(AdminSession).delete()
            session.query(AdminUser).delete()
            session.query(ContactLead).delete()
            session.add(
                AdminUser(
                    id='admin-super',
                    email='admin@starkids.kz',
                    full_name='Platform Admin',
                    password_hash=hash_password('StrongPass123!'),
                    role='super_admin',
                    is_active=True,
                )
            )
            session.commit()

    def test_contact_lead_submit_persists_and_returns_created_response(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/leads/contact',
            json={
                'name': 'Dana',
                'phone': '+77070000002',
                'email': 'dana@example.com',
                'message': 'Нужна консультация по услугам.',
            },
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()['type'], 'contact')
        self.assertEqual(response.json()['status'], 'new')

        with self.SessionLocal() as session:
            saved = session.scalar(
                select(ContactLead).where(ContactLead.id == response.json()['id'])
            )
            self.assertIsNotNone(saved)
            self.assertEqual(saved.customer_name, 'Dana')
            self.assertEqual(saved.phone, '+77070000002')
            self.assertIsNone(saved.mobile_user_id)
            self.assertEqual(saved.email, 'dana@example.com')
            self.assertEqual(saved.message, 'Нужна консультация по услугам.')

    def test_contact_lead_is_visible_in_admin_inbox_and_detail(self) -> None:
        submit_response = self.client.post(
            '/api/v1/mobile/leads/contact',
            json={
                'name': 'Dana',
                'phone': '+77070000002',
                'email': 'dana@example.com',
                'message': 'Нужна консультация по услугам.',
            },
        )
        lead_id = submit_response.json()['id']

        inbox_response = self.client.get(
            '/api/v1/admin/leads',
            headers=self._auth_headers(),
        )

        self.assertEqual(inbox_response.status_code, 200)
        self.assertEqual(inbox_response.json()['total'], 1)
        self.assertEqual(
            inbox_response.json()['items'][0],
            {
                'id': lead_id,
                'type': 'contact',
                'status': 'new',
                'source': 'mobile_app',
                'customerName': 'Dana',
                'phone': '+77070000002',
                'guestCount': None,
                'requestedDate': None,
                'createdAt': inbox_response.json()['items'][0]['createdAt'],
                'branch': None,
                'package': None,
            },
        )

        detail_response = self.client.get(
            f'/api/v1/admin/leads/{lead_id}',
            headers=self._auth_headers(),
        )

        self.assertEqual(detail_response.status_code, 200)
        self.assertEqual(
            detail_response.json(),
            {
                'id': lead_id,
                'type': 'contact',
                'status': 'new',
                'source': 'mobile_app',
                'customerName': 'Dana',
                'phone': '+77070000002',
                'guestCount': None,
                'requestedDate': None,
                'createdAt': detail_response.json()['createdAt'],
                'branch': None,
                'package': None,
                'email': 'dana@example.com',
                'notes': 'Нужна консультация по услугам.',
                'contactMethod': 'phone',
            },
        )

    def test_contact_lead_status_can_be_updated_from_admin_inbox(self) -> None:
        with self.SessionLocal() as session:
            session.add(
                ContactLead(
                    id='contact-lead',
                    customer_name='Dana',
                    phone='+77070000002',
                    email=None,
                    message='Перезвоните после обеда',
                    status='new',
                    source='mobile_app',
                    created_at=datetime(2026, 4, 8, 9, 0, tzinfo=UTC),
                )
            )
            session.commit()

        response = self.client.patch(
            '/api/v1/admin/leads/contact-lead/status',
            headers=self._auth_headers(),
            json={'status': 'in_progress'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['type'], 'contact')
        self.assertEqual(response.json()['status'], 'in_progress')

    def _auth_headers(self) -> dict[str, str]:
        login_response = self.client.post(
            '/api/v1/admin/auth/login',
            json={
                'email': 'admin@starkids.kz',
                'password': 'StrongPass123!',
            },
        )
        access_token = login_response.json()['access_token']
        return {'Authorization': f'Bearer {access_token}'}
