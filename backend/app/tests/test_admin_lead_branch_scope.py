from __future__ import annotations

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
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.contact_lead import ContactLead
from app.db.models.branch import Branch
from app.main import app


class AdminLeadBranchScopeTests(unittest.TestCase):
    PASSWORD = 'StrongPass123!'

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
            session.query(AdminUser).delete()
            session.query(BirthdayRequest).delete()
            session.query(ContactLead).delete()
            session.query(Branch).delete()
            session.add_all(
                [
                    self._branch('branch-a', 'Branch A', active=True),
                    self._branch('branch-b', 'Branch B', active=True),
                    self._branch('branch-inactive', 'Inactive', active=False),
                    AdminUser(
                        id='admin-super', email='super@example.com', full_name='Super',
                        password_hash=hash_password(self.PASSWORD), role='super_admin', is_active=True,
                    ),
                    AdminUser(
                        id='admin-sales', email='sales@example.com', full_name='Sales',
                        password_hash=hash_password(self.PASSWORD), role='sales_manager', is_active=True,
                    ),
                    AdminUser(
                        id='admin-operator-a', email='operator-a@example.com', full_name='Operator A',
                        password_hash=hash_password(self.PASSWORD), role='operator', branch_id='branch-a', is_active=True,
                    ),
                    AdminUser(
                        id='admin-operator-none', email='operator-none@example.com', full_name='Operator None',
                        password_hash=hash_password(self.PASSWORD), role='operator', branch_id=None, is_active=True,
                    ),
                    AdminUser(
                        id='admin-operator-inactive', email='operator-inactive@example.com', full_name='Operator Inactive',
                        password_hash=hash_password(self.PASSWORD), role='operator', branch_id='branch-inactive', is_active=True,
                    ),
                    AdminUser(
                        id='admin-content', email='content@example.com', full_name='Content',
                        password_hash=hash_password(self.PASSWORD), role='content_manager', is_active=True,
                    ),
                    BirthdayRequest(
                        id='lead-a', branch_id='branch-a', customer_name='Amina', phone='+77070000001',
                        source='mobile_app', status='new', created_at=datetime.now(UTC),
                    ),
                    BirthdayRequest(
                        id='lead-b', branch_id='branch-b', customer_name='Boris', phone='+77070000002',
                        source='mobile_app', status='new', created_at=datetime.now(UTC),
                    ),
                    ContactLead(
                        id='contact-1', customer_name='Contact', phone='+77070000003',
                        source='mobile_app', status='new', created_at=datetime.now(UTC),
                    ),
                ]
            )
            session.commit()

    @staticmethod
    def _branch(branch_id: str, name: str, *, active: bool) -> Branch:
        return Branch(
            id=branch_id,
            slug=branch_id,
            name=name,
            city='Shymkent',
            address='Address',
            short_label=name,
            working_hours='11:00 - 23:00',
            description=name,
            phone='+77070000000',
            whatsapp_phone='+77070000000',
            gallery_image_urls=[],
            facilities=[],
            display_order=1,
            is_active=active,
        )

    def _headers(self, email: str) -> dict[str, str]:
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={'email': email, 'password': self.PASSWORD},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}

    def test_content_manager_is_denied_all_lead_endpoints(self) -> None:
        headers = self._headers('content@example.com')
        self.assertEqual(self.client.get('/api/v1/admin/leads', headers=headers).status_code, 403)
        self.assertEqual(self.client.get('/api/v1/admin/leads/lead-a', headers=headers).status_code, 403)
        self.assertEqual(self.client.get('/api/v1/admin/leads/lead-a/birthday', headers=headers).status_code, 403)
        self.assertEqual(
            self.client.patch(
                '/api/v1/admin/leads/lead-a/status',
                headers=headers,
                json={'status': 'contacted'},
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.get(
                '/api/v1/admin/leads/birthday/operations-summary', headers=headers,
            ).status_code,
            403,
        )

    def test_unauthenticated_lead_request_is_rejected(self) -> None:
        self.assertEqual(self.client.get('/api/v1/admin/leads').status_code, 401)

    def test_super_admin_and_sales_manager_remain_global(self) -> None:
        for email in ('super@example.com', 'sales@example.com'):
            headers = self._headers(email)
            response = self.client.get('/api/v1/admin/leads', headers=headers)
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual({item['id'] for item in response.json()['items']}, {'lead-a', 'lead-b', 'contact-1'})
            self.assertEqual(self.client.get('/api/v1/admin/leads/lead-b', headers=headers).status_code, 200)

    def test_operator_is_scoped_to_assigned_branch_and_excludes_contacts(self) -> None:
        headers = self._headers('operator-a@example.com')
        response = self.client.get('/api/v1/admin/leads', headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual([item['id'] for item in response.json()['items']], ['lead-a'])

        same_branch = self.client.get('/api/v1/admin/leads', headers=headers, params={'branchId': 'branch-a'})
        self.assertEqual(same_branch.status_code, 200)
        self.assertEqual([item['id'] for item in same_branch.json()['items']], ['lead-a'])

        foreign_branch = self.client.get('/api/v1/admin/leads', headers=headers, params={'branchId': 'branch-b'})
        self.assertEqual(foreign_branch.status_code, 403)
        self.assertEqual(foreign_branch.json()['error']['code'], 'branch_access_denied')

        self.assertEqual(self.client.get('/api/v1/admin/leads/lead-a', headers=headers).status_code, 200)
        foreign_detail = self.client.get('/api/v1/admin/leads/lead-b', headers=headers)
        self.assertEqual(foreign_detail.status_code, 404)
        self.assertNotIn('+77070000002', foreign_detail.text)
        self.assertEqual(self.client.get('/api/v1/admin/leads/contact-1', headers=headers).status_code, 404)

    def test_operator_detail_and_mutation_are_branch_scoped_without_side_effect(self) -> None:
        headers = self._headers('operator-a@example.com')
        self.assertEqual(self.client.get('/api/v1/admin/leads/lead-a/birthday', headers=headers).status_code, 200)
        foreign_birthday_detail = self.client.get('/api/v1/admin/leads/lead-b/birthday', headers=headers)
        self.assertEqual(foreign_birthday_detail.status_code, 404)
        self.assertNotIn('+77070000002', foreign_birthday_detail.text)

        denied = self.client.patch(
            '/api/v1/admin/leads/lead-b/status',
            headers=headers,
            json={'status': 'contacted', 'paidAmountTenge': 99999},
        )
        self.assertEqual(denied.status_code, 404)
        with self.SessionLocal() as session:
            lead = session.scalar(select(BirthdayRequest).where(BirthdayRequest.id == 'lead-b'))
            self.assertEqual(lead.status, 'new')
            self.assertIsNone(lead.paid_amount_tenge)

        self.assertEqual(
            self.client.patch(
                '/api/v1/admin/leads/lead-a/status',
                headers=headers,
                json={'status': 'contacted'},
            ).status_code,
            200,
        )
        self.assertEqual(self.client.patch('/api/v1/admin/leads/contact-1/status', headers=headers, json={'status': 'in_progress'}).status_code, 404)

    def test_operator_assignment_and_branch_activity_fail_closed(self) -> None:
        self.assertEqual(self.client.get('/api/v1/admin/leads', headers=self._headers('operator-none@example.com')).status_code, 403)
        self.assertEqual(self.client.get('/api/v1/admin/leads', headers=self._headers('operator-inactive@example.com')).status_code, 403)

    def test_operations_summary_is_scoped_for_operator_and_global_for_managers(self) -> None:
        operator_summary = self.client.get(
            '/api/v1/admin/leads/birthday/operations-summary',
            headers=self._headers('operator-a@example.com'),
            params={'period': 'today'},
        )
        self.assertEqual(operator_summary.status_code, 200, operator_summary.text)
        self.assertEqual(operator_summary.json()['leadsCreated'], 1)

        for email in ('super@example.com', 'sales@example.com'):
            summary = self.client.get(
                '/api/v1/admin/leads/birthday/operations-summary',
                headers=self._headers(email),
                params={'period': 'today'},
            )
            self.assertEqual(summary.status_code, 200, summary.text)
            self.assertEqual(summary.json()['leadsCreated'], 2)
