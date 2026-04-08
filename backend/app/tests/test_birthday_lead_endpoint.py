from datetime import date
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.birthday_package import BirthdayPackage
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.branch import Branch
from app.main import app


class BirthdayLeadEndpointTests(unittest.TestCase):
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
        cls.non_raising_client = TestClient(app, raise_server_exceptions=False)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(BirthdayRequest).delete()
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
            other_branch = Branch(
                id='branch-other',
                slug='branch-other',
                name='Star Kids Other',
                city='Shymkent',
                address='Tauke Khan',
                short_label='Other',
                working_hours='11:00 - 22:00',
                description='Other branch',
                phone='+77070000001',
                whatsapp_phone='+77070000001',
                hero_image_url=None,
                gallery_image_urls=[],
                facilities=[],
                display_order=2,
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
            other_package = BirthdayPackage(
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

            session.add_all([branch, other_branch, package, other_package])
            session.commit()

    def test_success_submit_uses_frontend_contract_and_persists_request(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            json={
                'name': 'Amina',
                'phone': '+77070000000',
                'branchId': 'branch-main',
                'preferredDate': str(date.today()),
                'guestCount': 12,
                'comment': 'Нужен аниматор и фотозона.',
                'packageId': 'package-main',
            },
        )

        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(set(body.keys()), {'requestId', 'submittedAt', 'nextStep'})
        self.assertTrue(body['requestId'])
        self.assertEqual(
            body['nextStep'],
            'Менеджер свяжется с вами для подтверждения деталей',
        )
        self.assertTrue(body['submittedAt'].endswith('Z'))

        with self.SessionLocal() as session:
            saved = session.scalar(
                select(BirthdayRequest).where(BirthdayRequest.id == body['requestId'])
            )
            self.assertIsNotNone(saved)
            self.assertEqual(saved.customer_name, 'Amina')
            self.assertEqual(saved.phone, '+77070000000')
            self.assertIsNone(saved.mobile_user_id)
            self.assertEqual(saved.branch_id, 'branch-main')
            self.assertEqual(saved.birthday_package_id, 'package-main')
            self.assertEqual(saved.guest_count, 12)
            self.assertEqual(saved.notes, 'Нужен аниматор и фотозона.')

    def test_success_response_shape_matches_frontend_contract_exactly(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            json={
                'name': 'Amina',
                'phone': '+77070000000',
                'branchId': 'branch-main',
            },
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(
            sorted(response.json().keys()),
            ['nextStep', 'requestId', 'submittedAt'],
        )
        self.assertTrue(response.json()['submittedAt'].endswith('Z'))

    def test_missing_phone_uses_frontend_error_shape(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            json={
                'name': 'Amina',
                'branchId': 'branch-main',
            },
        )

        self.assertEqual(response.status_code, 422)
        self.assertEqual(
            response.json(),
            {
                'message': 'Validation error',
                'errors': {
                    'phone': ['Введите номер телефона'],
                },
            },
        )

    def test_invalid_phone_uses_frontend_error_shape(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            json={
                'name': 'Amina',
                'phone': '123',
                'branchId': 'branch-main',
            },
        )

        self.assertEqual(response.status_code, 422)
        self.assertEqual(
            response.json(),
            {
                'message': 'Validation error',
                'errors': {
                    'phone': ['Введите корректный номер'],
                },
            },
        )

    def test_package_branch_mismatch_uses_frontend_error_shape(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            json={
                'name': 'Amina',
                'phone': '+77070000000',
                'branchId': 'branch-main',
                'packageId': 'package-other',
            },
        )

        self.assertEqual(response.status_code, 422)
        self.assertEqual(
            response.json(),
            {
                'message': 'Validation error',
                'errors': {
                    'packageId': [
                        'Selected package must belong to the selected branch.'
                    ]
                },
            },
        )

    def test_generic_error_uses_exact_frontend_shape(self) -> None:
        with patch(
            'app.modules.leads.service.LeadService.create_birthday_lead',
            side_effect=RuntimeError('boom'),
        ):
            response = self.non_raising_client.post(
                '/api/v1/mobile/leads/birthday',
                json={
                    'name': 'Amina',
                    'phone': '+77070000000',
                    'branchId': 'branch-main',
                },
            )

        self.assertEqual(response.status_code, 500)
        self.assertEqual(
            response.json(),
            {'message': 'Не удалось отправить заявку'},
        )

    def test_route_is_available_only_via_canonical_public_path(self) -> None:
        canonical_response = self.client.post(
            '/api/v1/mobile/leads/birthday',
            json={
                'name': 'Amina',
                'phone': '+77070000000',
                'branchId': 'branch-main',
            },
        )
        legacy_response = self.client.post(
            '/api/v1/mobile/requests/birthday',
            json={
                'name': 'Amina',
                'phone': '+77070000000',
                'branchId': 'branch-main',
            },
        )

        self.assertEqual(canonical_response.status_code, 201)
        self.assertEqual(legacy_response.status_code, 404)
