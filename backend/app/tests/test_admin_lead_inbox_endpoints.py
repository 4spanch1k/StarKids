from datetime import UTC, date, datetime
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.security.passwords import hash_password
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.birthday_package import BirthdayPackage
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.branch import Branch
from app.main import app


class AdminLeadInboxEndpointTests(unittest.TestCase):
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
            session.query(BirthdayRequest).delete()
            session.query(BirthdayPackage).delete()
            session.query(Branch).delete()

            branch_main = Branch(
                id='branch-main',
                slug='branch-main',
                name='Star Kids Main',
                city='Shymkent',
                address='Al-Farabi',
                short_label='Main',
                working_hours='11:00 - 23:00',
                description='Main branch',
                phone='+77070000000',
                whatsapp_phone='+77070000000',
                hero_image_url=None,
                gallery_image_urls=[],
                facilities=[],
                display_order=1,
                is_active=True,
            )
            branch_other = Branch(
                id='branch-other',
                slug='branch-other',
                name='Star Kids North',
                city='Shymkent',
                address='Tauke Khan',
                short_label='North',
                working_hours='10:00 - 22:00',
                description='North branch',
                phone='+77070000001',
                whatsapp_phone='+77070000001',
                hero_image_url=None,
                gallery_image_urls=[],
                facilities=[],
                display_order=2,
                is_active=True,
            )
            package_main = BirthdayPackage(
                id='package-main',
                branch_id='branch-main',
                slug='package-main',
                name='Spark Party',
                price_from=55000,
                price_label='от 55 000 ₸',
                guest_capacity_label='до 10 детей',
                description='Main package',
                highlights=['Animator'],
                image_url=None,
                is_featured=False,
                is_active=True,
                display_order=1,
            )
            package_other = BirthdayPackage(
                id='package-other',
                branch_id='branch-other',
                slug='package-other',
                name='Star Show',
                price_from=85000,
                price_label='от 85 000 ₸',
                guest_capacity_label='до 15 детей',
                description='Other package',
                highlights=['Show'],
                image_url=None,
                is_featured=False,
                is_active=True,
                display_order=2,
            )
            admin_user = AdminUser(
                id='admin-super',
                email='admin@starkids.kz',
                full_name='Platform Admin',
                password_hash=hash_password('StrongPass123!'),
                role='super_admin',
                is_active=True,
            )
            request_new = BirthdayRequest(
                id='lead-new',
                branch_id='branch-main',
                birthday_package_id='package-main',
                customer_name='Amina',
                phone='+77070000000',
                guest_count=12,
                requested_date=date(2026, 4, 18),
                contact_method='phone',
                notes='Позвонить после 15:00',
                source='mobile_app',
                status='new',
                created_at=datetime(2026, 4, 1, 9, 0, tzinfo=UTC),
            )
            request_in_progress = BirthdayRequest(
                id='lead-in-progress',
                branch_id='branch-main',
                birthday_package_id=None,
                customer_name='Dana',
                phone='+77070000002',
                guest_count=8,
                requested_date=date(2026, 4, 19),
                contact_method='whatsapp',
                notes=None,
                source='mobile_app',
                status='in_progress',
                created_at=datetime(2026, 4, 2, 12, 0, tzinfo=UTC),
            )
            request_closed = BirthdayRequest(
                id='lead-closed',
                branch_id='branch-other',
                birthday_package_id='package-other',
                customer_name='Timur',
                phone='+77070000003',
                guest_count=15,
                requested_date=date(2026, 4, 20),
                contact_method='phone',
                notes='Уже обработано',
                source='mobile_app',
                status='closed',
                created_at=datetime(2026, 4, 3, 18, 30, tzinfo=UTC),
            )

            session.add_all(
                [
                    branch_main,
                    branch_other,
                    package_main,
                    package_other,
                    admin_user,
                    request_new,
                    request_in_progress,
                    request_closed,
                ]
            )
            session.commit()

    def test_admin_leads_require_authentication(self) -> None:
        response = self.client.get('/api/v1/admin/leads')

        self.assertEqual(response.status_code, 401)

    def test_list_admin_leads_returns_inbox_ready_items_and_filters(self) -> None:
        response = self.client.get(
            '/api/v1/admin/leads',
            headers=self._auth_headers(),
            params={
                'branchId': 'branch-main',
                'status': 'new',
                'createdFrom': '2026-04-01',
                'createdTo': '2026-04-01',
            },
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['total'], 1)
        self.assertEqual(len(body['items']), 1)
        self.assertEqual(
            body['items'][0],
            {
                'id': 'lead-new',
                'type': 'birthday_request',
                'status': 'new',
                'source': 'mobile_app',
                'customerName': 'Amina',
                'phone': '+77070000000',
                'guestCount': 12,
                'requestedDate': '2026-04-18',
                'createdAt': '2026-04-01T09:00:00Z',
                'branch': {
                    'id': 'branch-main',
                    'name': 'Star Kids Main',
                    'shortLabel': 'Main',
                },
                'package': {
                    'id': 'package-main',
                    'name': 'Spark Party',
                },
            },
        )

    def test_get_admin_lead_returns_detail_card(self) -> None:
        response = self.client.get(
            '/api/v1/admin/leads/lead-in-progress',
            headers=self._auth_headers(),
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                'id': 'lead-in-progress',
                'type': 'birthday_request',
                'status': 'in_progress',
                'source': 'mobile_app',
                'customerName': 'Dana',
                'phone': '+77070000002',
                'guestCount': 8,
                'requestedDate': '2026-04-19',
                'createdAt': '2026-04-02T12:00:00Z',
                'branch': {
                    'id': 'branch-main',
                    'name': 'Star Kids Main',
                    'shortLabel': 'Main',
                },
                'package': None,
                'email': None,
                'notes': None,
                'contactMethod': 'whatsapp',
            },
        )

    def test_patch_admin_lead_status_updates_allowed_transition(self) -> None:
        response = self.client.patch(
            '/api/v1/admin/leads/lead-new/status',
            headers=self._auth_headers(),
            json={'status': 'in_progress'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['status'], 'in_progress')

        detail_response = self.client.get(
            '/api/v1/admin/leads/lead-new',
            headers=self._auth_headers(),
        )
        self.assertEqual(detail_response.status_code, 200)
        self.assertEqual(detail_response.json()['status'], 'in_progress')

    def test_patch_admin_lead_status_rejects_invalid_transition(self) -> None:
        response = self.client.patch(
            '/api/v1/admin/leads/lead-closed/status',
            headers=self._auth_headers(),
            json={'status': 'in_progress'},
        )

        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()['error']['code'], 'invalid_lead_status_transition')

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
