import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.birthday_package import BirthdayPackage
from app.db.models.branch import Branch
from app.db.models.branch_menu_category import BranchMenuCategory
from app.db.models.branch_menu_item import BranchMenuItem
from app.db.models.branch_ticket_item import BranchTicketItem
from app.db.models.branch_ticket_note import BranchTicketNote
from app.db.models.promotion import Promotion
from app.db.models.promotion_branch import PromotionBranch
from app.main import app


class MobileBranchIdentifierContractTests(unittest.TestCase):
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
            session.query(PromotionBranch).delete()
            session.query(Promotion).delete()
            session.query(BranchTicketNote).delete()
            session.query(BranchTicketItem).delete()
            session.query(BranchMenuItem).delete()
            session.query(BranchMenuCategory).delete()
            session.query(BirthdayPackage).delete()
            session.query(Branch).delete()

            branch = Branch(
                id='7d9da50798f74a719f2d37f198e1735f',
                slug='shymkent-mega',
                name='Star Kids Al-Farabi',
                city='Shymkent',
                address='Al-Farabi 10',
                short_label='Аль-Фараби',
                working_hours='11:00 - 23:00',
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
            session.add(branch)
            session.add(
                BirthdayPackage(
                    id='6c21300524124da498025f198e51bd97',
                    branch_id=branch.id,
                    slug='magic-party',
                    name='Magic Party',
                    price_from=55000,
                    price_label='от 55 000 ₸',
                    guest_capacity_label='до 10 детей',
                    description='Package',
                    highlights=['Animator'],
                    image_url='https://cdn.example/package.jpg',
                    is_featured=True,
                    is_active=True,
                    display_order=1,
                )
            )

            menu_category = BranchMenuCategory(
                id='73cd4004089d468bb5d9c4aef2686c76',
                branch_id=branch.id,
                key='soups',
                title='Супы',
                display_order=1,
                is_active=True,
            )
            session.add(menu_category)
            session.add(
                BranchMenuItem(
                    id='ef88a1806e5f42a28b94f23eaa8fe2e2',
                    branch_id=branch.id,
                    category_id=menu_category.id,
                    title='Куриный суп',
                    price_tenge=1490,
                    image_url='https://cdn.example/soup.jpg',
                    display_order=1,
                    is_active=True,
                )
            )

            session.add_all(
                [
                    BranchTicketItem(
                        id='daa5e77bcaab4d939814987ba1f456b7',
                        branch_id=branch.id,
                        title='Детские билеты 1–3 лет',
                        description='Для подтверждения возраста понадобится документ.',
                        price_tenge=2700,
                        badge_labels=['Документ обязателен'],
                        display_order=1,
                        is_active=True,
                    ),
                    BranchTicketNote(
                        id='f3aa7efed27441ca812ecf59d3da2f39',
                        branch_id=branch.id,
                        text='Детям 0–1 лет — бесплатно',
                        display_order=1,
                        is_active=True,
                    ),
                ]
            )

            promotion = Promotion(
                id='promo-family-weekday',
                title='Weekday family offer',
                description='Discounted weekday entry for families.',
                badge_label='Weekday',
                image_url='https://cdn.example/promo.jpg',
                cta_label='See details',
                display_order=1,
                is_active=True,
                is_published=True,
            )
            session.add(promotion)
            session.add(
                PromotionBranch(
                    promotion_id=promotion.id,
                    branch_id=branch.id,
                )
            )
            session.commit()

    def test_mobile_birthday_packages_accept_branch_slug(self) -> None:
        response = self.client.get(
            '/api/v1/mobile/birthday-packages',
            params={'branch_id': 'shymkent-mega'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 1)
        self.assertEqual(
            response.json()[0]['branch_id'],
            '7d9da50798f74a719f2d37f198e1735f',
        )

    def test_mobile_menu_and_tickets_accept_branch_slug(self) -> None:
        menu_response = self.client.get('/api/v1/mobile/branches/shymkent-mega/menu')
        tickets_response = self.client.get('/api/v1/mobile/branches/shymkent-mega/tickets')

        self.assertEqual(menu_response.status_code, 200)
        self.assertEqual(
            menu_response.json()['branch_id'],
            '7d9da50798f74a719f2d37f198e1735f',
        )
        self.assertEqual(
            menu_response.json()['categories'][0]['items'][0]['title'],
            'Куриный суп',
        )

        self.assertEqual(tickets_response.status_code, 200)
        self.assertEqual(
            tickets_response.json()['branch_id'],
            '7d9da50798f74a719f2d37f198e1735f',
        )
        self.assertEqual(
            tickets_response.json()['items'][0]['id'],
            'daa5e77bcaab4d939814987ba1f456b7',
        )

    def test_mobile_promotions_accept_branch_slug(self) -> None:
        response = self.client.get(
            '/api/v1/mobile/promotions',
            params={'branch_id': 'shymkent-mega'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 1)
        self.assertEqual(response.json()[0]['id'], 'promo-family-weekday')
        self.assertEqual(
            response.json()[0]['branch_ids'],
            ['7d9da50798f74a719f2d37f198e1735f'],
        )
