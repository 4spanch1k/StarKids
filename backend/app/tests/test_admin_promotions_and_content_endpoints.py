import unittest
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.security.passwords import hash_password
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.branch import Branch
from app.db.models.content_block import ContentBlock
from app.db.models.faq_entry import FAQEntry
from app.db.models.promotion import Promotion
from app.db.models.promotion_branch import PromotionBranch
from app.main import app


class AdminPromotionsAndContentEndpointTests(unittest.TestCase):
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
            session.query(PromotionBranch).delete()
            session.query(Promotion).delete()
            session.query(FAQEntry).delete()
            session.query(ContentBlock).delete()
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
            session.add_all(
                [
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
                        facilities=[],
                        display_order=1,
                        is_active=True,
                    ),
                    Branch(
                        id='branch-north',
                        slug='branch-north',
                        name='Star Kids North',
                        city='Shymkent',
                        address='Tauke Khan 9',
                        short_label='North',
                        working_hours='11:00 - 23:00',
                        description='North branch description',
                        phone='+77070000001',
                        whatsapp_phone='+77070000001',
                        map_url=None,
                        route_label=None,
                        parking_hint=None,
                        arrival_hint=None,
                        hero_image_url=None,
                        gallery_image_urls=[],
                        facilities=[],
                        display_order=2,
                        is_active=True,
                    ),
                ]
            )
            session.commit()

    def test_admin_promotion_create_and_mobile_read_only_returns_published_active_items(self) -> None:
        create_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={
                'title': 'Weekday family offer',
                'description': 'Discounted weekday entry for families.',
                'badge_label': 'Weekday',
                'image_url': 'https://cdn.example/promo.jpg',
                'branch_ids': ['branch-main'],
                'cta_label': 'See details',
                'display_order': 1,
                'is_active': True,
                'is_published': False,
            },
        )
        self.assertEqual(create_response.status_code, 200)
        promotion_id = create_response.json()['id']

        mobile_hidden_response = self.client.get(
            '/api/v1/mobile/promotions',
            params={'branch_id': 'branch-main'},
        )
        self.assertEqual(mobile_hidden_response.status_code, 200)
        self.assertEqual(mobile_hidden_response.json(), [])

        publish_response = self.client.patch(
            f'/api/v1/admin/promotions/{promotion_id}',
            headers=self._auth_headers(),
            json={'is_published': True},
        )
        self.assertEqual(publish_response.status_code, 200)
        self.assertTrue(publish_response.json()['is_published'])

        mobile_visible_response = self.client.get(
            '/api/v1/mobile/promotions',
            params={'branch_id': 'branch-main'},
        )
        self.assertEqual(mobile_visible_response.status_code, 200)
        self.assertEqual(
            mobile_visible_response.json(),
            [
                {
                    'id': promotion_id,
                    'title': 'Weekday family offer',
                    'description': 'Discounted weekday entry for families.',
                    'badge_label': 'Weekday',
                    'image_url': 'https://cdn.example/promo.jpg',
                    'branch_ids': ['branch-main'],
                    'cta_label': 'See details',
                }
            ],
        )

    def test_admin_faqs_mobile_list_only_returns_published_active_entries(self) -> None:
        create_response = self.client.post(
            '/api/v1/admin/faqs',
            headers=self._auth_headers(),
            json={
                'question': 'Can we bring our own cake?',
                'answer': 'Yes, but please confirm in advance.',
                'display_order': 1,
                'is_active': True,
                'is_published': False,
            },
        )
        self.assertEqual(create_response.status_code, 200)
        faq_id = create_response.json()['id']

        mobile_hidden_response = self.client.get('/api/v1/mobile/faqs')
        self.assertEqual(mobile_hidden_response.status_code, 200)
        self.assertEqual(mobile_hidden_response.json(), [])

        publish_response = self.client.patch(
            f'/api/v1/admin/faqs/{faq_id}',
            headers=self._auth_headers(),
            json={'is_published': True},
        )
        self.assertEqual(publish_response.status_code, 200)

        mobile_visible_response = self.client.get('/api/v1/mobile/faqs')
        self.assertEqual(mobile_visible_response.status_code, 200)
        self.assertEqual(
            mobile_visible_response.json(),
            [
                {
                    'id': faq_id,
                    'question': 'Can we bring our own cake?',
                    'answer': 'Yes, but please confirm in advance.',
                }
            ],
        )

    def test_mobile_promotions_respect_validity_window_and_state(self) -> None:
        now = datetime.now(UTC)
        promotion_payload = {
            'title': 'Timed family offer',
            'description': 'A promotion visible only during its configured window.',
            'badge_label': 'Limited',
            'image_url': 'https://cdn.example/timed.jpg',
            'branch_ids': ['branch-main'],
            'cta_label': 'See details',
            'display_order': 1,
            'is_active': True,
            'is_published': True,
            'start_at': (now - timedelta(days=1)).isoformat(),
            'end_at': (now + timedelta(days=1)).isoformat(),
        }
        visible_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json=promotion_payload,
        )
        self.assertEqual(visible_response.status_code, 200)
        self.assertTrue(visible_response.json()['start_at'].endswith('Z'))
        self.assertTrue(visible_response.json()['end_at'].endswith('Z'))

        future_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={
                **promotion_payload,
                'title': 'Future offer',
                'start_at': (now + timedelta(days=1)).isoformat(),
                'end_at': (now + timedelta(days=2)).isoformat(),
            },
        )
        self.assertEqual(future_response.status_code, 200)

        expired_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={
                **promotion_payload,
                'title': 'Expired offer',
                'start_at': (now - timedelta(days=2)).isoformat(),
                'end_at': (now - timedelta(days=1)).isoformat(),
            },
        )
        self.assertEqual(expired_response.status_code, 200)

        no_dates_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={
                **promotion_payload,
                'title': 'Always-on offer',
                'display_order': 2,
                'start_at': None,
                'end_at': None,
            },
        )
        self.assertEqual(no_dates_response.status_code, 200)

        inactive_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={**promotion_payload, 'title': 'Inactive offer', 'is_active': False},
        )
        self.assertEqual(inactive_response.status_code, 200)

        unpublished_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={**promotion_payload, 'title': 'Draft offer', 'is_published': False},
        )
        self.assertEqual(unpublished_response.status_code, 200)

        other_branch_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={**promotion_payload, 'title': 'North offer', 'branch_ids': ['branch-north']},
        )
        self.assertEqual(other_branch_response.status_code, 200)

        mobile_response = self.client.get(
            '/api/v1/mobile/promotions',
            params={'branch_id': 'branch-main'},
        )
        self.assertEqual(mobile_response.status_code, 200)
        self.assertEqual(
            [item['title'] for item in mobile_response.json()],
            ['Timed family offer', 'Always-on offer'],
        )

    def test_promotion_validity_window_rejects_non_increasing_dates(self) -> None:
        response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={
                'title': 'Invalid window',
                'description': 'A promotion with an invalid validity window.',
                'badge_label': 'Invalid',
                'image_url': None,
                'branch_ids': [],
                'cta_label': 'See details',
                'display_order': 1,
                'is_active': True,
                'is_published': True,
                'start_at': '2026-09-20T12:00:00Z',
                'end_at': '2026-09-20T12:00:00Z',
            },
        )
        self.assertEqual(response.status_code, 422)

        valid_response = self.client.post(
            '/api/v1/admin/promotions',
            headers=self._auth_headers(),
            json={
                'title': 'Valid window',
                'description': 'A promotion with a valid validity window.',
                'badge_label': 'Valid',
                'image_url': None,
                'branch_ids': [],
                'cta_label': 'See details',
                'display_order': 1,
                'is_active': True,
                'is_published': True,
                'start_at': '2026-09-20T12:00:00Z',
                'end_at': '2026-09-21T12:00:00Z',
            },
        )
        self.assertEqual(valid_response.status_code, 200)
        update_response = self.client.patch(
            f"/api/v1/admin/promotions/{valid_response.json()['id']}",
            headers=self._auth_headers(),
            json={'end_at': '2026-09-20T11:00:00Z'},
        )
        self.assertEqual(update_response.status_code, 422)

    def test_admin_content_blocks_mobile_surface_filter_only_returns_published_active(self) -> None:
        create_home_response = self.client.post(
            '/api/v1/admin/content-blocks',
            headers=self._auth_headers(),
            json={
                'surface': 'home',
                'key': 'birthday-hero',
                'title': 'Celebrate birthdays with us',
                'body': 'Book a package and the team will confirm the details.',
                'cta_label': 'View packages',
                'display_order': 1,
                'is_active': True,
                'is_published': False,
            },
        )
        self.assertEqual(create_home_response.status_code, 200)
        home_block_id = create_home_response.json()['id']

        create_contacts_response = self.client.post(
            '/api/v1/admin/content-blocks',
            headers=self._auth_headers(),
            json={
                'surface': 'contacts',
                'key': 'parking-note',
                'title': 'Parking',
                'body': 'Guest parking is available behind the building.',
                'display_order': 1,
                'is_active': True,
                'is_published': True,
            },
        )
        self.assertEqual(create_contacts_response.status_code, 200)

        publish_home_response = self.client.patch(
            f'/api/v1/admin/content-blocks/{home_block_id}',
            headers=self._auth_headers(),
            json={'is_published': True},
        )
        self.assertEqual(publish_home_response.status_code, 200)

        mobile_home_response = self.client.get(
            '/api/v1/mobile/content-blocks',
            params={'surface': 'home'},
        )
        self.assertEqual(mobile_home_response.status_code, 200)
        self.assertEqual(
            mobile_home_response.json(),
            [
                {
                    'id': home_block_id,
                    'surface': 'home',
                    'key': 'birthday-hero',
                    'title': 'Celebrate birthdays with us',
                    'body': 'Book a package and the team will confirm the details.',
                    'cta_label': 'View packages',
                }
            ],
        )

        mobile_contacts_response = self.client.get(
            '/api/v1/mobile/content-blocks',
            params={'surface': 'contacts'},
        )
        self.assertEqual(mobile_contacts_response.status_code, 200)
        self.assertEqual(len(mobile_contacts_response.json()), 1)
        self.assertEqual(mobile_contacts_response.json()[0]['surface'], 'contacts')

    def test_admin_content_block_rejects_duplicate_surface_key(self) -> None:
        first_response = self.client.post(
            '/api/v1/admin/content-blocks',
            headers=self._auth_headers(),
            json={
                'surface': 'home',
                'key': 'birthday-hero',
                'title': 'Celebrate birthdays',
                'body': 'Primary birthday CTA.',
                'display_order': 1,
                'is_active': True,
                'is_published': True,
            },
        )
        self.assertEqual(first_response.status_code, 200)

        duplicate_response = self.client.post(
            '/api/v1/admin/content-blocks',
            headers=self._auth_headers(),
            json={
                'surface': 'home',
                'key': 'birthday-hero',
                'title': 'Duplicate hero',
                'body': 'Duplicate body.',
                'display_order': 2,
                'is_active': True,
                'is_published': True,
            },
        )
        self.assertEqual(duplicate_response.status_code, 422)
        self.assertEqual(
            duplicate_response.json()['error']['code'],
            'content_block_key_taken',
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
