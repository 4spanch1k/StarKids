from datetime import date
import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config.settings import get_settings
from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.branch import Branch
from app.db.models.branch_ticket_item import BranchTicketItem
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.main import app
from app.modules.mobile_payments.dependencies import get_freedompay_client
from app.modules.mobile_payments.freedompay_client import FreedomPayInitResult
from app.modules.mobile_payments.signing import build_freedompay_signature


class FakeFreedomPayClient:
    def init_payment(self, params: dict[str, object]) -> FreedomPayInitResult:
        order_id = str(params['pg_order_id'])
        return FreedomPayInitResult(
            external_payment_id=f'fp-{order_id}',
            payment_url=f'https://pay.test/{order_id}',
            raw_payload={
                'pg_status': 'ok',
                'pg_payment_id': f'fp-{order_id}',
                'pg_redirect_url': f'https://pay.test/{order_id}',
            },
        )


class MobileFreedomPaymentsEndpointTests(unittest.TestCase):
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

        settings = get_settings()
        cls._original_freedompay_settings = {
            'freedompay_merchant_id': settings.freedompay_merchant_id,
            'freedompay_secret_key': settings.freedompay_secret_key,
            'freedompay_result_url': settings.freedompay_result_url,
            'freedompay_success_url': settings.freedompay_success_url,
            'freedompay_failure_url': settings.freedompay_failure_url,
            'freedompay_mock_mode': settings.freedompay_mock_mode,
        }
        settings.freedompay_merchant_id = 'test-merchant'
        settings.freedompay_secret_key = 'test-secret'
        settings.freedompay_result_url = (
            'https://api.starkids.test/api/v1/public/payments/freedom/result'
        )
        settings.freedompay_success_url = 'starkids://payments/success'
        settings.freedompay_failure_url = 'starkids://payments/failure'
        settings.freedompay_mock_mode = False

        def override_get_db_session():
            session = cls.SessionLocal()
            try:
                yield session
            finally:
                session.close()

        app.dependency_overrides[get_db_session] = override_get_db_session
        app.dependency_overrides[get_freedompay_client] = lambda: FakeFreedomPayClient()
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        settings = get_settings()
        for key, value in cls._original_freedompay_settings.items():
            setattr(settings, key, value)
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(MobilePayment).delete()
            session.query(BranchTicketItem).delete()
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.query(Branch).delete()
            session.add(
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
                )
            )
            session.add(
                BranchTicketItem(
                    id='ticket-kids',
                    branch_id='branch-main',
                    title='Детский билет',
                    description='2 часа посещения',
                    price_tenge=2700,
                    badge_labels=[],
                    display_order=1,
                    is_active=True,
                )
            )
            session.commit()

    def test_freedompay_ticket_payment_flow_is_backend_confirmed_and_idempotent(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        auth_headers = {'Authorization': f"Bearer {auth['access_token']}"}

        init_response = self.client.post(
            '/api/v1/mobile/payments/freedom/init',
            headers=auth_headers,
            json={
                'ticketItems': [
                    {
                        'ticketItemId': 'ticket-kids',
                        'quantity': 2,
                    }
                ],
                'visitDate': str(date.today()),
            },
        )

        self.assertEqual(init_response.status_code, 200)
        init_body = init_response.json()
        self.assertEqual(init_body['status'], 'pending')
        self.assertTrue(init_body['paymentUrl'].startswith('https://pay.test/'))

        status_response = self.client.get(
            f"/api/v1/mobile/payments/{init_body['paymentId']}",
            headers=auth_headers,
        )
        self.assertEqual(status_response.status_code, 200)
        self.assertEqual(status_response.json()['status'], 'pending')
        self.assertEqual(status_response.json()['amountTenge'], 5400)

        callback_payload = self._signed_callback_payload(
            order_id=init_body['localOrderId'],
            payment_id=init_body['externalPaymentId'],
            amount='5400',
            result='1',
        )
        callback_response = self.client.post(
            '/api/v1/public/payments/freedom/result',
            data=callback_payload,
        )

        self.assertEqual(callback_response.status_code, 200)
        self.assertIn('<pg_status>ok</pg_status>', callback_response.text)

        paid_status_response = self.client.get(
            f"/api/v1/mobile/payments/{init_body['paymentId']}",
            headers=auth_headers,
        )
        self.assertEqual(paid_status_response.status_code, 200)
        self.assertEqual(paid_status_response.json()['status'], 'paid')

        first_tickets_response = self.client.get(
            '/api/v1/mobile/tickets/purchases',
            headers=auth_headers,
        )
        self.assertEqual(first_tickets_response.status_code, 200)
        self.assertEqual(first_tickets_response.json()['total'], 1)
        self.assertEqual(
            first_tickets_response.json()['items'][0]['items'][0]['quantity'],
            2,
        )

        retry_callback_response = self.client.post(
            '/api/v1/public/payments/freedom/result',
            data=callback_payload,
        )
        self.assertEqual(retry_callback_response.status_code, 200)
        self.assertIn('<pg_status>ok</pg_status>', retry_callback_response.text)

        second_tickets_response = self.client.get(
            '/api/v1/mobile/tickets/purchases',
            headers=auth_headers,
        )
        self.assertEqual(second_tickets_response.json()['total'], 1)

    def test_freedompay_callback_rejects_invalid_signature(self) -> None:
        response = self.client.post(
            '/api/v1/public/payments/freedom/result',
            data={
                'pg_order_id': 'unknown',
                'pg_payment_id': 'fp-invalid',
                'pg_amount': '100',
                'pg_currency': 'KZT',
                'pg_result': '1',
                'pg_salt': 'gateway-salt',
                'pg_sig': 'invalid',
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn('<pg_status>error</pg_status>', response.text)
        self.assertIn('Invalid signature', response.text)

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

    def _signed_callback_payload(
        self,
        *,
        order_id: str,
        payment_id: str,
        amount: str,
        result: str,
    ) -> dict[str, str]:
        payload = {
            'pg_order_id': order_id,
            'pg_payment_id': payment_id,
            'pg_amount': amount,
            'pg_currency': 'KZT',
            'pg_result': result,
            'pg_payment_date': '2026-04-13 10:00:00',
            'pg_can_reject': '1',
            'pg_salt': 'gateway-salt',
        }
        payload['pg_sig'] = build_freedompay_signature(
            script_name='result',
            params=payload,
            secret_key='test-secret',
        )
        return payload
