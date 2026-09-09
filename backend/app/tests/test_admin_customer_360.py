from datetime import UTC, date, datetime
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.core.rate_limit.service import reset_rate_limit_state
from app.core.security.passwords import hash_password
from app.db.models import Base
from app.db.models.admin_session import AdminSession
from app.db.models.admin_user import AdminUser
from app.db.models.birthday_package import BirthdayPackage
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.branch import Branch
from app.db.models.loyalty_account import LoyaltyAccount
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_user import MobileUser
from app.db.models.visit import Visit
from app.main import app


class AdminCustomer360EndpointTests(unittest.TestCase):
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
        reset_rate_limit_state()
        with self.SessionLocal() as session:
            for model in (
                Visit,
                BirthdayRequest,
                LoyaltyAccount,
                MobilePayment,
                MobileChild,
                MobileUser,
                BirthdayPackage,
                Branch,
                AdminSession,
                AdminUser,
            ):
                session.query(model).delete()

            branch = Branch(
                id='branch-main',
                slug='main',
                name='Boom Bala Main',
                city='Almaty',
                address='Abay 1',
                short_label='Main',
                working_hours='10:00-22:00',
                description='Main branch',
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
            )
            package = BirthdayPackage(
                id='package-main',
                branch_id=branch.id,
                slug='spark',
                name='Spark Party',
                price_from=55000,
                price_label='от 55 000 ₸',
                guest_capacity_label='до 10 детей',
                description='Birthday package',
                highlights=['Animator'],
                image_url=None,
                is_featured=False,
                is_active=True,
                display_order=1,
            )
            alice = MobileUser(
                id='user-alice',
                phone='+77071111111',
                email='alice@example.com',
                first_name='Айжан',
                last_name='Садыкова',
                is_active=True,
                created_at=datetime(2026, 1, 1, tzinfo=UTC),
            )
            bob = MobileUser(
                id='user-bob',
                phone='+77072222222',
                email=None,
                first_name=None,
                last_name=None,
                is_active=False,
                created_at=datetime(2026, 2, 1, tzinfo=UTC),
            )
            children = [
                MobileChild(
                    id=f'child-{index}',
                    user_id=alice.id,
                    name=name,
                    birth_date=date(2020, 5, index + 1),
                    gender='unspecified',
                    created_at=datetime(2026, 1, index + 1, tzinfo=UTC),
                )
                for index, name in enumerate(('Алина', 'Али', 'Алиса'))
            ]
            payments = [
                MobilePayment(
                    id='payment-cash',
                    mobile_user_id=alice.id,
                    branch_id=branch.id,
                    payable_entity_type='branch_ticket_order',
                    payable_entity_id='order-cash',
                    local_order_id='BB-CASH',
                    idempotency_key='payment-cash-key',
                    amount_tenge=2500,
                    gross_amount_tenge=3500,
                    bonus_amount=1000,
                    cash_amount_tenge=2500,
                    currency='KZT',
                    quantity=1,
                    visit_date=date(2026, 5, 10),
                    ticket_items=[],
                    status='paid',
                    paid_at=datetime(2026, 5, 10, 9, tzinfo=UTC),
                    init_payload={},
                    callback_payload={},
                ),
                MobilePayment(
                    id='payment-bonus',
                    mobile_user_id=alice.id,
                    branch_id=branch.id,
                    payable_entity_type='branch_ticket_order',
                    payable_entity_id='order-bonus',
                    local_order_id='BB-BONUS',
                    idempotency_key='payment-bonus-key',
                    amount_tenge=0,
                    gross_amount_tenge=3500,
                    bonus_amount=3500,
                    cash_amount_tenge=0,
                    currency='KZT',
                    quantity=1,
                    visit_date=date(2026, 6, 20),
                    ticket_items=[],
                    status='paid',
                    paid_at=datetime(2026, 6, 20, 9, tzinfo=UTC),
                    init_payload={},
                    callback_payload={},
                ),
                MobilePayment(
                    id='payment-failed',
                    mobile_user_id=alice.id,
                    branch_id=branch.id,
                    payable_entity_type='branch_ticket_order',
                    payable_entity_id='order-failed',
                    local_order_id='BB-FAILED',
                    idempotency_key='payment-failed-key',
                    amount_tenge=3500,
                    gross_amount_tenge=3500,
                    bonus_amount=0,
                    cash_amount_tenge=3500,
                    currency='KZT',
                    quantity=1,
                    visit_date=date(2026, 9, 5),
                    ticket_items=[],
                    status='failed',
                    init_payload={},
                    callback_payload={},
                ),
            ]
            visits = [
                Visit(
                    id='visit-first',
                    mobile_payment_id='payment-cash',
                    mobile_user_id=alice.id,
                    branch_id=branch.id,
                    status='completed',
                    started_at=datetime(2026, 5, 10, 11, tzinfo=UTC),
                    ended_at=datetime(2026, 5, 10, 14, tzinfo=UTC),
                ),
                Visit(
                    id='visit-last',
                    mobile_payment_id='payment-bonus',
                    mobile_user_id=alice.id,
                    branch_id=branch.id,
                    status='active',
                    started_at=datetime(2026, 9, 5, 11, tzinfo=UTC),
                    ended_at=None,
                ),
            ]
            request = BirthdayRequest(
                id='birthday-alice',
                mobile_user_id=alice.id,
                branch_id=branch.id,
                birthday_package_id=package.id,
                child_id='child-1',
                customer_name='Айжан Садыкова',
                phone=alice.phone,
                child_name='Алина',
                child_age=6,
                guest_count=12,
                requested_date=date(2026, 9, 20),
                contact_method='phone',
                notes='Позвонить после 15:00',
                source='mobile_app',
                status='new',
                idempotency_key='birthday-idempotency',
                child_name_snapshot='Алина',
                child_birth_date_snapshot=date(2020, 5, 1),
                package_name_snapshot='Spark Party',
                package_price_snapshot=55000,
            )
            loyalty = LoyaltyAccount(
                id='loyalty-alice',
                mobile_user_id=alice.id,
                balance=1200,
                reserved_balance=0,
                lifetime_earned=5000,
                lifetime_spent=3800,
            )
            super_admin = AdminUser(
                id='admin-super',
                email='admin@example.com',
                full_name='Platform Admin',
                password_hash=hash_password('StrongPass123!'),
                role='super_admin',
                is_active=True,
            )
            operator = AdminUser(
                id='admin-operator',
                email='operator@example.com',
                full_name='Operator',
                password_hash=hash_password('StrongPass123!'),
                role='operator',
                is_active=True,
            )
            content_manager = AdminUser(
                id='admin-content',
                email='content@example.com',
                full_name='Content Manager',
                password_hash=hash_password('StrongPass123!'),
                role='content_manager',
                is_active=True,
            )
            sales_manager = AdminUser(
                id='admin-sales',
                email='sales@example.com',
                full_name='Sales Manager',
                password_hash=hash_password('StrongPass123!'),
                role='sales_manager',
                is_active=True,
            )
            session.add_all([branch, package, alice, bob, *children, *payments, *visits, request, loyalty, super_admin, operator, content_manager, sales_manager])
            session.commit()

    def test_customer_endpoints_require_super_admin(self) -> None:
        self.assertEqual(self.client.get('/api/v1/admin/customers').status_code, 401)

        for email in ('operator@example.com', 'content@example.com', 'sales@example.com'):
            role_headers = self._auth_headers(email)
            self.assertEqual(
                self.client.get('/api/v1/admin/customers', headers=role_headers).status_code,
                403,
            )
            self.assertEqual(
                self.client.get('/api/v1/admin/customers/user-alice', headers=role_headers).status_code,
                403,
            )

    def test_customer_list_is_paginated_searchable_and_uses_real_metrics(self) -> None:
        response = self.client.get(
            '/api/v1/admin/customers',
            headers=self._auth_headers('admin@example.com'),
            params={'search': 'alice@example.com', 'page': 1, 'pageSize': 1},
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['total'], 1)
        self.assertEqual(body['page'], 1)
        self.assertEqual(body['pageSize'], 1)
        item = body['items'][0]
        self.assertEqual(
            {key: value for key, value in item.items() if key != 'daysSinceLastVisit'},
            {
                'id': 'user-alice',
                'firstName': 'Айжан',
                'lastName': 'Садыкова',
                'phone': '+77071111111',
                'email': 'alice@example.com',
                'childrenCount': 3,
                'visitsCount': 2,
                'firstVisitAt': '2026-05-10T11:00:00Z',
                'lastVisitAt': '2026-09-05T11:00:00Z',
                'customerVisitType': 'returning',
                'ticketCashSpendTenge': 2500,
                'bonusBalance': 1200,
                'createdAt': '2026-01-01T00:00:00Z',
            },
        )
        self.assertIsInstance(item['daysSinceLastVisit'], int)

    def test_customer_list_pages_are_deterministic(self) -> None:
        headers = self._auth_headers('admin@example.com')

        first_page = self.client.get(
            '/api/v1/admin/customers',
            headers=headers,
            params={'page': 1, 'pageSize': 1},
        )
        second_page = self.client.get(
            '/api/v1/admin/customers',
            headers=headers,
            params={'page': 2, 'pageSize': 1},
        )

        self.assertEqual(first_page.status_code, 200)
        self.assertEqual(second_page.status_code, 200)
        self.assertEqual(first_page.json()['total'], 2)
        self.assertEqual([item['id'] for item in first_page.json()['items']], ['user-alice'])
        self.assertEqual([item['id'] for item in second_page.json()['items']], ['user-bob'])

    def test_customer_detail_keeps_payment_and_visit_semantics_separate(self) -> None:
        response = self.client.get(
            '/api/v1/admin/customers/user-alice',
            headers=self._auth_headers('admin@example.com'),
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['metrics']['childrenCount'], 3)
        self.assertEqual(body['metrics']['visitsCount'], 2)
        self.assertEqual(body['metrics']['firstVisitAt'], '2026-05-10T11:00:00Z')
        self.assertEqual(body['metrics']['lastVisitAt'], '2026-09-05T11:00:00Z')
        self.assertIsInstance(body['metrics']['daysSinceLastVisit'], int)
        self.assertEqual(body['metrics']['customerVisitType'], 'returning')
        self.assertEqual(body['metrics']['ticketCashSpendTenge'], 2500)
        self.assertEqual(body['loyalty'], {'balance': 1200, 'lifetimeEarned': 5000, 'lifetimeSpent': 3800})
        self.assertEqual(len(body['children']), 3)
        self.assertEqual(len(body['recentVisits']), 2)
        self.assertEqual(len(body['recentTicketPurchases']), 3)
        self.assertEqual(body['recentTicketPurchases'][0]['cashAmountTenge'], 0)
        self.assertEqual(body['recentTicketPurchases'][2]['status'], 'failed')
        self.assertEqual(body['metrics']['ticketCashSpendTenge'], 2500)
        self.assertEqual(body['birthdayLeads'][0]['packageName'], 'Spark Party')

    def test_legacy_customer_without_loyalty_or_visits_is_safe(self) -> None:
        response = self.client.get(
            '/api/v1/admin/customers/user-bob',
            headers=self._auth_headers('admin@example.com'),
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['customer']['phone'], '+77072222222')
        self.assertEqual(body['metrics']['visitsCount'], 0)
        self.assertIsNone(body['metrics']['firstVisitAt'])
        self.assertIsNone(body['metrics']['lastVisitAt'])
        self.assertIsNone(body['metrics']['daysSinceLastVisit'])
        self.assertEqual(body['metrics']['customerVisitType'], 'never_visited')
        self.assertEqual(body['loyalty'], {'balance': 0, 'lifetimeEarned': 0, 'lifetimeSpent': 0})
        self.assertEqual(body['children'], [])
        self.assertEqual(body['recentTicketPurchases'], [])

    def test_search_and_pagination_do_not_expose_unrelated_customers(self) -> None:
        headers = self._auth_headers('admin@example.com')
        self.assertEqual(
            self.client.get('/api/v1/admin/customers', headers=headers, params={'search': 'Садыкова'}).json()['total'],
            1,
        )
        self.assertEqual(
            self.client.get('/api/v1/admin/customers', headers=headers, params={'search': '+77072222222'}).json()['total'],
            1,
        )
        self.assertEqual(
            self.client.get('/api/v1/admin/customers/unknown', headers=headers).status_code,
            404,
        )

    def test_customer_list_supports_derived_visit_segment_filters(self) -> None:
        headers = self._auth_headers('admin@example.com')
        for segment, expected_ids in (
            ('never_visited', ['user-bob']),
            ('first_visit_only', []),
            ('returning', ['user-alice']),
        ):
            response = self.client.get(
                '/api/v1/admin/customers',
                headers=headers,
                params={'visitSegment': segment},
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual([item['id'] for item in response.json()['items']], expected_ids)

    def _auth_headers(self, email: str) -> dict[str, str]:
        response = self.client.post(
            '/api/v1/admin/auth/login',
            json={'email': email, 'password': 'StrongPass123!'},
        )
        self.assertEqual(response.status_code, 200)
        return {'Authorization': f"Bearer {response.json()['access_token']}"}
