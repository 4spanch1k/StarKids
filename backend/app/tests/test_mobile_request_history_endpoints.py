from datetime import date, datetime, timedelta, timezone
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
from app.db.models.contact_lead import ContactLead
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.main import app


class MobileRequestHistoryEndpointTests(unittest.TestCase):
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
            session.query(BirthdayRequest).delete()
            session.query(ContactLead).delete()
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.query(BirthdayPackage).delete()
            session.query(Branch).delete()

            branch = Branch(
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
            package = BirthdayPackage(
                id='package-main',
                branch_id='branch-main',
                slug='package-main',
                name='Spark Party',
                price_from=55000,
                price_label='от 55 000 ₸',
                guest_capacity_label='до 10 детей',
                description='Package',
                highlights=['Animator'],
                image_url=None,
                is_featured=False,
                is_active=True,
                display_order=1,
            )

            session.add_all([branch, package])
            session.commit()

    def test_history_requires_authenticated_mobile_user(self) -> None:
        response = self.client.get('/api/v1/mobile/me/requests')

        self.assertEqual(response.status_code, 401)

    def test_authenticated_submit_links_birthday_and_contact_leads_to_current_mobile_user(self) -> None:
        user_one = self._authenticate_mobile_user('+77071234567')
        user_two = self._authenticate_mobile_user('+77070001122')

        birthday_response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            headers={'Authorization': f"Bearer {user_one['access_token']}"},
            json={
                'name': 'Amina',
                'phone': '+77071234567',
                'branchId': 'branch-main',
                'preferredDate': str(date.today()),
                'guestCount': 12,
                'comment': 'Нужен аниматор и фотозона.',
                'packageId': 'package-main',
            },
        )
        self.assertEqual(birthday_response.status_code, 201)

        contact_response = self.client.post(
            '/api/v1/mobile/leads/contact',
            headers={'Authorization': f"Bearer {user_one['access_token']}"},
            json={
                'name': 'Amina',
                'phone': '+77071234567',
                'email': 'amina@example.com',
                'message': 'Подскажите свободные даты.',
            },
        )
        self.assertEqual(contact_response.status_code, 201)

        anonymous_response = self.client.post(
            '/api/v1/mobile/leads/contact',
            json={
                'name': 'Guest',
                'phone': '+77070000002',
                'email': 'guest@example.com',
                'message': 'Анонимная заявка.',
            },
        )
        self.assertEqual(anonymous_response.status_code, 201)

        history_response = self.client.get(
            '/api/v1/mobile/me/requests',
            headers={'Authorization': f"Bearer {user_one['access_token']}"},
        )

        self.assertEqual(history_response.status_code, 200)
        body = history_response.json()
        self.assertEqual(body['total'], 2)
        items_by_type = {item['type']: item for item in body['items']}
        self.assertEqual(set(items_by_type.keys()), {'contact', 'birthday_request'})

        contact_item = items_by_type['contact']
        self.assertEqual(contact_item['id'], contact_response.json()['id'])
        self.assertEqual(contact_item['status'], 'new')
        self.assertEqual(contact_item['notes'], 'Подскажите свободные даты.')
        self.assertIsNone(contact_item['branch'])
        self.assertIsNone(contact_item['package'])

        birthday_item = items_by_type['birthday_request']
        self.assertEqual(birthday_item['id'], birthday_response.json()['requestId'])
        self.assertEqual(birthday_item['status'], 'new')
        self.assertEqual(birthday_item['requestedDate'], str(date.today()))
        self.assertEqual(birthday_item['guestCount'], 12)
        self.assertEqual(birthday_item['notes'], 'Нужен аниматор и фотозона.')
        self.assertEqual(
            birthday_item['branch'],
            {
                'id': 'branch-main',
                'name': 'Star Kids Main',
                'shortLabel': 'Main',
            },
        )
        self.assertEqual(
            birthday_item['package'],
            {
                'id': 'package-main',
                'name': 'Spark Party',
            },
        )

        other_user_history_response = self.client.get(
            '/api/v1/mobile/me/requests',
            headers={'Authorization': f"Bearer {user_two['access_token']}"},
        )
        self.assertEqual(other_user_history_response.status_code, 200)
        self.assertEqual(other_user_history_response.json(), {'items': [], 'total': 0})

        with self.SessionLocal() as session:
            saved_birthday = session.scalar(
                select(BirthdayRequest).where(
                    BirthdayRequest.id == birthday_response.json()['requestId']
                )
            )
            saved_contact = session.scalar(
                select(ContactLead).where(
                    ContactLead.id == contact_response.json()['id']
                )
            )
            anonymous_contact = session.scalar(
                select(ContactLead).where(
                    ContactLead.id == anonymous_response.json()['id']
                )
            )

            self.assertIsNotNone(saved_birthday)
            self.assertIsNotNone(saved_contact)
            self.assertIsNotNone(anonymous_contact)
            self.assertEqual(saved_birthday.mobile_user_id, user_one['user']['id'])
            self.assertEqual(saved_contact.mobile_user_id, user_one['user']['id'])
            self.assertIsNone(anonymous_contact.mobile_user_id)

    def test_history_items_are_returned_newest_first(self) -> None:
        user = self._authenticate_mobile_user('+77075550000')

        birthday_response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            headers={'Authorization': f"Bearer {user['access_token']}"},
            json={
                'name': 'Dana',
                'phone': '+77075550000',
                'branchId': 'branch-main',
                'preferredDate': str(date.today()),
                'guestCount': 8,
                'comment': 'Утренний слот.',
                'packageId': 'package-main',
            },
        )
        self.assertEqual(birthday_response.status_code, 201)

        contact_response = self.client.post(
            '/api/v1/mobile/leads/contact',
            headers={'Authorization': f"Bearer {user['access_token']}"},
            json={
                'name': 'Dana',
                'phone': '+77075550000',
                'email': 'dana@example.com',
                'message': 'Хочу уточнить детали.',
            },
        )
        self.assertEqual(contact_response.status_code, 201)

        older_created_at = datetime.now(timezone.utc) - timedelta(days=1)
        newer_created_at = datetime.now(timezone.utc)
        with self.SessionLocal() as session:
            birthday_request = session.scalar(
                select(BirthdayRequest).where(
                    BirthdayRequest.id == birthday_response.json()['requestId']
                )
            )
            contact_lead = session.scalar(
                select(ContactLead).where(
                    ContactLead.id == contact_response.json()['id']
                )
            )
            self.assertIsNotNone(birthday_request)
            self.assertIsNotNone(contact_lead)
            birthday_request.created_at = older_created_at
            contact_lead.created_at = newer_created_at
            session.commit()

        history_response = self.client.get(
            '/api/v1/mobile/me/requests',
            headers={'Authorization': f"Bearer {user['access_token']}"},
        )

        self.assertEqual(history_response.status_code, 200)
        items = history_response.json()['items']
        self.assertEqual([item['type'] for item in items], ['contact', 'birthday_request'])
        self.assertEqual(
            [item['id'] for item in items],
            [contact_response.json()['id'], birthday_response.json()['requestId']],
        )

    def _authenticate_mobile_user(self, phone: str) -> dict[str, object]:
        response = self.client.post(
            '/api/v1/mobile/auth/verify-otp',
            json={
                'phone': phone,
                'code': '1234',
                'verification_id': f'otp_{phone[-4:]}',
            },
        )
        self.assertEqual(response.status_code, 200)
        return response.json()
