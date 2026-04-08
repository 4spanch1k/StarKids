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
from app.db.models.contact_lead import ContactLead
from app.main import app


class MobileLeadToAdminInboxFlowTests(unittest.TestCase):
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
            session.query(BirthdayRequest).delete()
            session.query(BirthdayPackage).delete()
            session.query(Branch).delete()

            session.add_all(
                [
                    Branch(
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
                    ),
                    BirthdayPackage(
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
                    ),
                    AdminUser(
                        id='admin-super',
                        email='admin@starkids.kz',
                        full_name='Platform Admin',
                        password_hash=hash_password('StrongPass123!'),
                        role='super_admin',
                        is_active=True,
                    ),
                ]
            )
            session.commit()

    def test_birthday_lead_submit_reaches_admin_inbox_with_selected_branch(self) -> None:
        submit_response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            json={
                'name': 'Amina',
                'phone': '+77070000000',
                'branchId': 'branch-main',
                'preferredDate': str(date.today()),
                'guestCount': 12,
                'comment': 'Нужен аниматор',
                'packageId': 'package-main',
            },
        )

        self.assertEqual(submit_response.status_code, 201)
        request_id = submit_response.json()['requestId']

        inbox_response = self.client.get(
            '/api/v1/admin/leads',
            headers=self._auth_headers(),
        )

        self.assertEqual(inbox_response.status_code, 200)
        self.assertEqual(inbox_response.json()['total'], 1)
        self.assertEqual(
            inbox_response.json()['items'][0],
            {
                'id': request_id,
                'type': 'birthday_request',
                'status': 'new',
                'source': 'mobile_app',
                'customerName': 'Amina',
                'phone': '+77070000000',
                'guestCount': 12,
                'requestedDate': str(date.today()),
                'createdAt': inbox_response.json()['items'][0]['createdAt'],
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
