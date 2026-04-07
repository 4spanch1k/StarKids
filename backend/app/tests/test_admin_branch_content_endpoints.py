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
from app.db.models.branch import Branch
from app.db.models.branch_pricing_profile import BranchPricingProfile
from app.db.models.branch_rule import BranchRule
from app.db.models.branch_tariff import BranchTariff
from app.main import app


class AdminBranchContentEndpointTests(unittest.TestCase):
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
            session.query(BirthdayPackage).delete()
            session.query(BranchRule).delete()
            session.query(BranchTariff).delete()
            session.query(BranchPricingProfile).delete()
            session.query(Branch).delete()

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
            session.add(
                Branch(
                    id='branch-main',
                    slug='branch-main',
                    name='Star Kids Main',
                    city='Shymkent',
                    address='Al-Farabi 10',
                    short_label='Main',
                    working_hours='10:00 - 22:00',
                    description='Main branch description',
                    phone='+77070000000',
                    whatsapp_phone='+77070000000',
                    map_url=None,
                    route_label=None,
                    parking_hint=None,
                    arrival_hint=None,
                    hero_image_url=None,
                    gallery_image_urls=[],
                    facilities=['Cafe'],
                    display_order=1,
                    is_active=True,
                )
            )
            session.commit()

    def test_admin_branch_create_update_and_mobile_visibility_follow_is_active(self) -> None:
        create_response = self.client.post(
            '/api/v1/admin/branches',
            headers=self._auth_headers(),
            json={
                'slug': 'branch-south',
                'name': 'Star Kids South',
                'city': 'Shymkent',
                'address': 'Auezov 12',
                'short_label': 'South',
                'working_hours': '11:00 - 23:00',
                'description': 'South branch',
                'phone': '+77070000001',
                'whatsapp_phone': '+77070000001',
                'display_order': 2,
                'is_active': True,
            },
        )

        self.assertEqual(create_response.status_code, 200)
        branch_id = create_response.json()['id']

        mobile_visible_response = self.client.get(
            '/api/v1/mobile/branches/branch-south',
        )
        self.assertEqual(mobile_visible_response.status_code, 200)

        archive_response = self.client.patch(
            f'/api/v1/admin/branches/{branch_id}',
            headers=self._auth_headers(),
            json={'is_active': False},
        )

        self.assertEqual(archive_response.status_code, 200)
        self.assertFalse(archive_response.json()['is_active'])

        mobile_hidden_response = self.client.get('/api/v1/mobile/branches/branch-south')
        self.assertEqual(mobile_hidden_response.status_code, 404)

    def test_branch_contacts_gallery_and_prices_rules_flow(self) -> None:
        contacts_response = self.client.put(
            '/api/v1/admin/branches/branch-main/contacts',
            headers=self._auth_headers(),
            json={
                'address': 'Al-Farabi 10',
                'phone': '+77070000000',
                'whatsapp_phone': '+77070000000',
                'map_url': 'https://maps.example/branch-main',
                'route_label': 'Open in 2GIS',
                'parking_hint': 'Parking behind the building',
                'arrival_hint': 'Use the east entrance',
            },
        )
        self.assertEqual(contacts_response.status_code, 200)

        gallery_response = self.client.put(
            '/api/v1/admin/branches/branch-main/gallery',
            headers=self._auth_headers(),
            json={
                'hero_image_url': 'https://cdn.example/hero.jpg',
                'gallery_image_urls': [
                    'https://cdn.example/gallery-1.jpg',
                    'https://cdn.example/gallery-2.jpg',
                ],
            },
        )
        self.assertEqual(gallery_response.status_code, 200)

        pricing_response = self.client.put(
            '/api/v1/admin/branches/branch-main/prices-rules',
            headers=self._auth_headers(),
            json={
                'intro_title': 'Prices and rules',
                'intro_description': 'Simple visit tariffs for walk-in guests.',
                'birthday_note': 'Birthday packages are booked separately.',
                'disclaimer': 'Prices may change on holidays.',
                'visit_tariffs': [
                    {
                        'title': 'Weekday visit',
                        'price_label': '4 000 ₸',
                        'description': 'Unlimited play on weekdays',
                        'display_order': 1,
                        'is_active': True,
                    }
                ],
                'rules': [
                    {
                        'text': 'Bring socks for every guest.',
                        'display_order': 1,
                        'is_active': True,
                    },
                    {
                        'text': 'Food from outside is not allowed.',
                        'display_order': 2,
                        'is_active': True,
                    },
                ],
            },
        )
        self.assertEqual(pricing_response.status_code, 200)
        self.assertEqual(pricing_response.json()['intro_title'], 'Prices and rules')

        mobile_contacts_response = self.client.get(
            '/api/v1/mobile/branches/branch-main/contacts',
        )
        self.assertEqual(mobile_contacts_response.status_code, 200)
        self.assertEqual(
            mobile_contacts_response.json(),
            {
                'branch_id': 'branch-main',
                'address': 'Al-Farabi 10',
                'phone': '+77070000000',
                'whatsapp_phone': '+77070000000',
                'map_url': 'https://maps.example/branch-main',
                'route_label': 'Open in 2GIS',
                'parking_hint': 'Parking behind the building',
                'arrival_hint': 'Use the east entrance',
            },
        )

        mobile_gallery_response = self.client.get(
            '/api/v1/mobile/branches/branch-main/gallery',
        )
        self.assertEqual(mobile_gallery_response.status_code, 200)
        self.assertEqual(
            mobile_gallery_response.json(),
            {
                'branch_id': 'branch-main',
                'hero_image_url': 'https://cdn.example/hero.jpg',
                'gallery_image_urls': [
                    'https://cdn.example/gallery-1.jpg',
                    'https://cdn.example/gallery-2.jpg',
                ],
            },
        )

        mobile_prices_rules_response = self.client.get(
            '/api/v1/mobile/branches/branch-main/prices-rules',
        )
        self.assertEqual(mobile_prices_rules_response.status_code, 200)
        self.assertEqual(
            mobile_prices_rules_response.json(),
            {
                'branch_id': 'branch-main',
                'intro_title': 'Prices and rules',
                'intro_description': 'Simple visit tariffs for walk-in guests.',
                'visit_tariffs': [
                    {
                        'id': mobile_prices_rules_response.json()['visit_tariffs'][0]['id'],
                        'title': 'Weekday visit',
                        'price_label': '4 000 ₸',
                        'description': 'Unlimited play on weekdays',
                    }
                ],
                'rules': [
                    'Bring socks for every guest.',
                    'Food from outside is not allowed.',
                ],
                'birthday_note': 'Birthday packages are booked separately.',
                'disclaimer': 'Prices may change on holidays.',
            },
        )

    def test_admin_birthday_package_create_update_and_mobile_list_respects_active_state(self) -> None:
        create_response = self.client.post(
            '/api/v1/admin/birthday-packages',
            headers=self._auth_headers(),
            json={
                'branch_id': 'branch-main',
                'slug': 'spark-party',
                'name': 'Spark Party',
                'price_from': 55000,
                'price_label': 'от 55 000 ₸',
                'guest_capacity_label': 'до 10 детей',
                'description': 'Base package',
                'highlights': ['Animator'],
                'image_url': 'https://cdn.example/package.jpg',
                'is_featured': True,
                'is_active': True,
                'display_order': 1,
            },
        )

        self.assertEqual(create_response.status_code, 200)
        package_id = create_response.json()['id']

        mobile_list_response = self.client.get(
            '/api/v1/mobile/birthday-packages',
            params={'branch_id': 'branch-main'},
        )
        self.assertEqual(mobile_list_response.status_code, 200)
        self.assertEqual(len(mobile_list_response.json()), 1)

        archive_response = self.client.patch(
            f'/api/v1/admin/birthday-packages/{package_id}',
            headers=self._auth_headers(),
            json={'is_active': False},
        )
        self.assertEqual(archive_response.status_code, 200)
        self.assertFalse(archive_response.json()['is_active'])

        mobile_hidden_response = self.client.get(
            '/api/v1/mobile/birthday-packages',
            params={'branch_id': 'branch-main'},
        )
        self.assertEqual(mobile_hidden_response.status_code, 200)
        self.assertEqual(mobile_hidden_response.json(), [])

    def test_admin_branch_routes_require_authentication(self) -> None:
        response = self.client.get('/api/v1/admin/branches')
        self.assertEqual(response.status_code, 401)

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
