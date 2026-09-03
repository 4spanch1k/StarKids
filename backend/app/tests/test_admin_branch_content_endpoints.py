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
from app.db.models.branch_menu_category import BranchMenuCategory
from app.db.models.branch_menu_item import BranchMenuItem
from app.db.models.branch_pricing_profile import BranchPricingProfile
from app.db.models.branch_rule import BranchRule
from app.db.models.branch_tariff import BranchTariff
from app.db.models.branch_ticket_item import BranchTicketItem
from app.db.models.branch_ticket_note import BranchTicketNote
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
            session.query(BranchTicketNote).delete()
            session.query(BranchTicketItem).delete()
            session.query(BranchMenuItem).delete()
            session.query(BranchMenuCategory).delete()
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

    def test_branch_menu_flow_from_admin_to_mobile(self) -> None:
        seeded_menu_response = self.client.get(
            '/api/v1/admin/branches/branch-main/menu',
            headers=self._auth_headers(),
        )
        self.assertEqual(seeded_menu_response.status_code, 200)
        self.assertEqual(
            seeded_menu_response.json()['categories'][0]['title'],
            'Супы',
        )
        self.assertGreaterEqual(len(seeded_menu_response.json()['items']), 1)

        update_response = self.client.put(
            '/api/v1/admin/branches/branch-main/menu',
            headers=self._auth_headers(),
            json={
                'categories': [
                    {
                        'key': 'soups',
                        'title': 'Супы',
                        'display_order': 1,
                        'is_active': True,
                    },
                    {
                        'key': 'tea',
                        'title': 'Чай',
                        'display_order': 2,
                        'is_active': True,
                    },
                ],
                'items': [
                    {
                        'title': 'Куриный суп с домашней лапшой',
                        'price_tenge': 1590,
                        'image_url': 'https://cdn.example/chicken-noodle-soup.jpg',
                        'category_key': 'soups',
                        'display_order': 1,
                        'is_active': True,
                    },
                    {
                        'title': 'Суп ребра',
                        'price_tenge': 1890,
                        'image_url': 'https://cdn.example/rib-soup.jpg',
                        'category_key': 'soups',
                        'display_order': 2,
                        'is_active': False,
                    },
                    {
                        'title': 'Чай с молоком',
                        'price_tenge': 1090,
                        'image_url': 'https://cdn.example/milk-tea.jpg',
                        'category_key': 'tea',
                        'display_order': 1,
                        'is_active': True,
                    },
                ],
            },
        )
        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(len(update_response.json()['categories']), 2)
        self.assertEqual(
            update_response.json()['items'][0]['image_url'],
            'https://cdn.example/chicken-noodle-soup.jpg',
        )

        mobile_menu_response = self.client.get(
            '/api/v1/mobile/branches/branch-main/menu',
        )
        self.assertEqual(mobile_menu_response.status_code, 200)
        self.assertEqual(
            mobile_menu_response.json(),
            {
                'branch_id': 'branch-main',
                'categories': [
                    {
                        'id': mobile_menu_response.json()['categories'][0]['id'],
                        'title': 'Супы',
                        'items': [
                            {
                                'id': mobile_menu_response.json()['categories'][0]['items'][0]['id'],
                                'title': 'Куриный суп с домашней лапшой',
                                'price_tenge': 1590,
                                'image_url': 'https://cdn.example/chicken-noodle-soup.jpg',
                            }
                        ],
                    },
                    {
                        'id': mobile_menu_response.json()['categories'][1]['id'],
                        'title': 'Чай',
                        'items': [
                            {
                                'id': mobile_menu_response.json()['categories'][1]['items'][0]['id'],
                                'title': 'Чай с молоком',
                                'price_tenge': 1090,
                                'image_url': 'https://cdn.example/milk-tea.jpg',
                            }
                        ],
                    },
                ],
            },
        )

    def test_branch_tickets_flow_from_admin_to_mobile(self) -> None:
        seeded_tickets_response = self.client.get(
            '/api/v1/admin/branches/branch-main/tickets',
            headers=self._auth_headers(),
        )
        self.assertEqual(seeded_tickets_response.status_code, 200)
        self.assertEqual(
            seeded_tickets_response.json()['items'][0]['title'],
            'Детские билеты 1–3 лет',
        )
        self.assertEqual(len(seeded_tickets_response.json()['notes']), 3)

        update_response = self.client.put(
            '/api/v1/admin/branches/branch-main/tickets',
            headers=self._auth_headers(),
            json={
                'items': [
                    {
                        'title': 'Детские билеты 1–3 лет',
                        'description': 'Для подтверждения возраста понадобится документ.',
                        'price_tenge': 2800,
                        'badge_labels': ['Документ обязателен'],
                        'display_order': 1,
                        'is_active': True,
                    },
                    {
                        'title': 'Семейный билет 2+1',
                        'description': 'Для двух взрослых и одного ребенка.',
                        'price_tenge': 7200,
                        'badge_labels': ['Семейный'],
                        'display_order': 2,
                        'is_active': True,
                    },
                    {
                        'title': 'Взрослый билет (сопровождающий)',
                        'description': 'Тариф для одного сопровождающего взрослого.',
                        'price_tenge': 400,
                        'badge_labels': ['Для сопровождающего'],
                        'display_order': 3,
                        'is_active': False,
                    },
                ],
                'notes': [
                    {
                        'text': 'Детям 0–1 лет — бесплатно',
                        'display_order': 1,
                        'is_active': True,
                    },
                    {
                        'text': 'Имениннику в день рождения — бесплатно',
                        'display_order': 2,
                        'is_active': True,
                    },
                    {
                        'text': 'Скрытая заметка',
                        'display_order': 3,
                        'is_active': False,
                    },
                ],
            },
        )
        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(len(update_response.json()['items']), 3)
        self.assertEqual(update_response.json()['items'][1]['title'], 'Семейный билет 2+1')

        mobile_tickets_response = self.client.get(
            '/api/v1/mobile/branches/branch-main/tickets',
        )
        self.assertEqual(mobile_tickets_response.status_code, 200)
        self.assertEqual(
            mobile_tickets_response.json(),
            {
                'branch_id': 'branch-main',
                'items': [
                    {
                        'id': mobile_tickets_response.json()['items'][0]['id'],
                        'title': 'Детские билеты 1–3 лет',
                        'description': 'Для подтверждения возраста понадобится документ.',
                        'price_tenge': 2800,
                        'badge_labels': ['Документ обязателен'],
                    },
                    {
                        'id': mobile_tickets_response.json()['items'][1]['id'],
                        'title': 'Семейный билет 2+1',
                        'description': 'Для двух взрослых и одного ребенка.',
                        'price_tenge': 7200,
                        'badge_labels': ['Семейный'],
                    },
                ],
                'notes': [
                    'Детям 0–1 лет — бесплатно',
                    'Имениннику в день рождения — бесплатно',
                ],
            },
        )

    def test_branch_tickets_are_scoped_per_branch(self) -> None:
        create_branch_response = self.client.post(
            '/api/v1/admin/branches',
            headers=self._auth_headers(),
            json={
                'slug': 'branch-south',
                'name': 'Star Kids South',
                'city': 'Shymkent',
                'address': 'Auezov 12',
                'short_label': 'South',
                'working_hours': '11:00 - 23:00',
                'description': 'South branch description',
                'phone': '+77070000001',
                'whatsapp_phone': '+77070000001',
                'display_order': 2,
                'is_active': True,
            },
        )
        self.assertEqual(create_branch_response.status_code, 200)
        south_branch_id = create_branch_response.json()['id']

        update_south_tickets_response = self.client.put(
            f'/api/v1/admin/branches/{south_branch_id}/tickets',
            headers=self._auth_headers(),
            json={
                'items': [
                    {
                        'title': 'Семейный билет South',
                        'description': 'Только для южного филиала.',
                        'price_tenge': 6500,
                        'badge_labels': ['South'],
                        'display_order': 1,
                        'is_active': True,
                    }
                ],
                'notes': [
                    {
                        'text': 'Только по южному филиалу',
                        'display_order': 1,
                        'is_active': True,
                    }
                ],
            },
        )
        self.assertEqual(update_south_tickets_response.status_code, 200)

        main_tickets_response = self.client.get('/api/v1/mobile/branches/branch-main/tickets')
        south_tickets_response = self.client.get('/api/v1/mobile/branches/branch-south/tickets')

        self.assertEqual(main_tickets_response.status_code, 200)
        self.assertEqual(south_tickets_response.status_code, 200)
        self.assertEqual(
            main_tickets_response.json()['items'][0]['title'],
            'Детские билеты 1–3 лет',
        )
        self.assertEqual(
            south_tickets_response.json(),
            {
                'branch_id': south_branch_id,
                'items': [
                    {
                        'id': south_tickets_response.json()['items'][0]['id'],
                        'title': 'Семейный билет South',
                        'description': 'Только для южного филиала.',
                        'price_tenge': 6500,
                        'badge_labels': ['South'],
                    }
                ],
                'notes': ['Только по южному филиалу'],
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
