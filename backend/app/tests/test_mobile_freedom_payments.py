from datetime import date
import hashlib
import unittest
from unittest.mock import patch
from urllib import parse

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config.settings import Settings, get_settings
from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.branch import Branch
from app.db.models.branch_ticket_item import BranchTicketItem
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_payment_callback import MobilePaymentCallback
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.repositories.mobile_payment_repository import MobilePaymentRepository
from app.main import app
from app.modules.mobile_payments.dependencies import get_freedompay_client
from app.modules.mobile_payments.freedompay_client import (
    FreedomPayClient,
    FreedomPayInitResult,
)
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


class FakeGatewayResponse:
    def __enter__(self) -> 'FakeGatewayResponse':
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def read(self) -> bytes:
        return (
            b'<response>'
            b'<pg_status>ok</pg_status>'
            b'<pg_payment_id>fp-transport</pg_payment_id>'
            b'<pg_redirect_url>https://pay.test/transport</pg_redirect_url>'
            b'</response>'
        )


class MobileFreedomPaymentsEndpointTests(unittest.TestCase):
    def test_freedompay_init_uses_urlencoded_form_transport(self) -> None:
        settings = Settings(
            freedompay_merchant_id='test-merchant',
            freedompay_secret_key='test-secret',
            freedompay_base_url='https://api.freedompay.kz',
            freedompay_result_url='https://api.starkids.test/freedom/result',
            freedompay_success_url='https://api.starkids.test/payment/success',
            freedompay_failure_url='https://api.starkids.test/payment/failure',
        )
        captured_requests = []

        def fake_urlopen(gateway_request, *, timeout: int):
            captured_requests.append((gateway_request, timeout))
            return FakeGatewayResponse()

        with patch(
            'app.modules.mobile_payments.freedompay_client.request.urlopen',
            side_effect=fake_urlopen,
        ):
            result = FreedomPayClient(settings).init_payment(
                {
                    'pg_order_id': 'order-1',
                    'pg_merchant_id': 'test-merchant',
                    'pg_amount': '1000',
                    'pg_currency': 'KZT',
                    'pg_description': 'Boom Bala ticket',
                    'pg_salt': 'salt',
                }
            )

        self.assertEqual(result.external_payment_id, 'fp-transport')
        gateway_request, timeout = captured_requests[0]
        self.assertEqual(timeout, settings.freedompay_request_timeout_seconds)
        self.assertEqual(gateway_request.get_method(), 'POST')
        self.assertEqual(
            gateway_request.get_header('Content-type'),
            'application/x-www-form-urlencoded',
        )
        request_body = parse.parse_qs(gateway_request.data.decode('utf-8'))
        self.assertEqual(request_body['pg_order_id'], ['order-1'])
        self.assertEqual(request_body['pg_amount'], ['1000'])
        self.assertIn('pg_sig', request_body)

    def test_freedompay_signature_matches_documented_flat_parameter_order(self) -> None:
        params = {
            'pg_amount': '100',
            'pg_description': 'test',
            'pg_merchant_id': '82',
            'pg_order_id': '123456',
            'pg_salt': 'some random string',
        }
        documented_source = (
            'init_payment.php;100;test;82;123456;some random string;secret_key'
        )

        signature = build_freedompay_signature(
            script_name='init_payment.php',
            params=params,
            secret_key='secret_key',
        )

        self.assertEqual(
            signature,
            hashlib.md5(documented_source.encode('utf-8')).hexdigest(),
        )

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
            session.query(MobilePaymentCallback).delete()
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
                'idempotencyKey': 'checkout-test-payment-1',
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
        auth = self._authenticate_mobile_user('+77071234567')
        payment = self._init_payment(
            {'Authorization': f"Bearer {auth['access_token']}"},
            'checkout-invalid-signature',
        )
        response = self.client.post(
            '/api/v1/public/payments/freedom/result',
            data={
                'pg_order_id': payment['localOrderId'],
                'pg_payment_id': payment['externalPaymentId'],
                'pg_amount': '2700',
                'pg_currency': 'KZT',
                'pg_result': '1',
                'pg_salt': 'gateway-salt',
                'pg_sig': 'invalid',
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn('<pg_status>error</pg_status>', response.text)
        self.assertIn('Invalid signature', response.text)
        status_response = self.client.get(
            f"/api/v1/mobile/payments/{payment['paymentId']}",
            headers={'Authorization': f"Bearer {auth['access_token']}"},
        )
        self.assertEqual(status_response.json()['status'], 'pending')

    def test_same_user_same_idempotency_key_reuses_one_payment(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        headers = {'Authorization': f"Bearer {auth['access_token']}"}
        first = self._init_payment(headers, 'checkout-same-key')
        second = self._init_payment(headers, 'checkout-same-key')

        self.assertEqual(first['paymentId'], second['paymentId'])
        with self.SessionLocal() as session:
            self.assertEqual(session.query(MobilePayment).count(), 1)

    def test_database_unique_constraint_rejects_duplicate_checkout_key(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        first = self._init_payment(
            {'Authorization': f"Bearer {auth['access_token']}"},
            'checkout-db-unique-key',
        )
        with self.SessionLocal() as session:
            user = session.scalar(select(MobileUser).where(MobileUser.phone == '+77071234567'))
            self.assertIsNotNone(user)
            repository = MobilePaymentRepository(session)
            with self.assertRaises(IntegrityError):
                repository.create_ticket_payment(
                    mobile_user_id=user.id,
                    branch_id='branch-main',
                    payable_entity_type='branch_ticket_order',
                    payable_entity_id='branch-main',
                    local_order_id='sk-db-duplicate-order',
                    idempotency_key='checkout-db-unique-key',
                    amount_tenge=2700,
                    currency='KZT',
                    quantity=1,
                    visit_date=None,
                    ticket_items=[{'ticketItemId': 'ticket-kids', 'quantity': 1}],
                    init_payload={},
                )
            session.rollback()
        self.assertTrue(first['paymentId'])

    def test_same_user_different_idempotency_keys_create_two_payments(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        headers = {'Authorization': f"Bearer {auth['access_token']}"}
        first = self._init_payment(headers, 'checkout-key-one')
        second = self._init_payment(headers, 'checkout-key-two')

        self.assertNotEqual(first['paymentId'], second['paymentId'])
        with self.SessionLocal() as session:
            self.assertEqual(session.query(MobilePayment).count(), 2)

    def test_same_idempotency_key_isolated_between_users(self) -> None:
        first_auth = self._authenticate_mobile_user('+77071234567')
        second_auth = self._authenticate_mobile_user('+77071234568')
        first = self._init_payment(
            {'Authorization': f"Bearer {first_auth['access_token']}"},
            'checkout-shared-key',
        )
        second = self._init_payment(
            {'Authorization': f"Bearer {second_auth['access_token']}"},
            'checkout-shared-key',
        )

        self.assertNotEqual(first['paymentId'], second['paymentId'])

    def test_paid_payment_cannot_regress_and_callbacks_are_audited(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        headers = {'Authorization': f"Bearer {auth['access_token']}"}
        payment = self._init_payment(headers, 'checkout-terminal-state')
        success = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id=payment['externalPaymentId'],
            amount='2700',
            result='1',
        )
        self.client.post('/api/v1/public/payments/freedom/result', data=success)
        duplicate_success = dict(success)
        duplicate_success['pg_payment_date'] = '2026-04-13 10:01:00'
        duplicate_success['pg_sig'] = build_freedompay_signature(
            script_name='result',
            params=duplicate_success,
            secret_key='test-secret',
        )
        self.client.post(
            '/api/v1/public/payments/freedom/result',
            data=duplicate_success,
        )
        late_failure = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id='fp-late-failure',
            amount='2700',
            result='0',
        )
        self.client.post('/api/v1/public/payments/freedom/result', data=late_failure)

        status_response = self.client.get(
            f"/api/v1/mobile/payments/{payment['paymentId']}",
            headers=headers,
        )
        self.assertEqual(status_response.json()['status'], 'paid')
        with self.SessionLocal() as session:
            callback_rows = session.scalars(
                select(MobilePaymentCallback).where(
                    MobilePaymentCallback.mobile_payment_id == payment['paymentId']
                )
            ).all()
            self.assertEqual(len(callback_rows), 2)
            self.assertEqual(callback_rows[0].duplicate_count, 1)

    def test_not_completed_keeps_pending_then_success_marks_paid(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        headers = {'Authorization': f"Bearer {auth['access_token']}"}
        payment = self._init_payment(headers, 'checkout-not-completed')
        not_completed = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id=payment['externalPaymentId'],
            amount='2700',
            result='2',
        )
        response = self.client.post(
            '/api/v1/public/payments/freedom/result',
            data=not_completed,
        )
        self.assertIn('<pg_status>ok</pg_status>', response.text)
        pending_status = self.client.get(
            f"/api/v1/mobile/payments/{payment['paymentId']}",
            headers=headers,
        )
        self.assertEqual(pending_status.json()['status'], 'pending')

        with self.SessionLocal() as session:
            callback = session.scalar(select(MobilePaymentCallback))
            self.assertIsNotNone(callback)
            self.assertEqual(callback.result, 'not_completed')

        success = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id=payment['externalPaymentId'],
            amount='2700',
            result='1',
        )
        self.client.post('/api/v1/public/payments/freedom/result', data=success)
        paid_status = self.client.get(
            f"/api/v1/mobile/payments/{payment['paymentId']}",
            headers=headers,
        )
        self.assertEqual(paid_status.json()['status'], 'paid')

    def test_paid_payment_ignores_not_completed_callback(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        headers = {'Authorization': f"Bearer {auth['access_token']}"}
        payment = self._init_payment(headers, 'checkout-paid-not-completed')
        success = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id=payment['externalPaymentId'],
            amount='2700',
            result='1',
        )
        self.client.post('/api/v1/public/payments/freedom/result', data=success)
        not_completed = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id=payment['externalPaymentId'],
            amount='2700',
            result='2',
        )
        self.client.post(
            '/api/v1/public/payments/freedom/result',
            data=not_completed,
        )

        status_response = self.client.get(
            f"/api/v1/mobile/payments/{payment['paymentId']}",
            headers=headers,
        )
        self.assertEqual(status_response.json()['status'], 'paid')
        with self.SessionLocal() as session:
            callbacks = session.scalars(
                select(MobilePaymentCallback).where(
                    MobilePaymentCallback.mobile_payment_id == payment['paymentId']
                )
            ).all()
            self.assertEqual([callback.result for callback in callbacks], ['success', 'not_completed'])

    def test_amount_mismatch_with_can_reject_zero_requires_reconciliation(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        headers = {'Authorization': f"Bearer {auth['access_token']}"}
        payment = self._init_payment(headers, 'checkout-reconciliation-required')
        mismatch = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id=payment['externalPaymentId'],
            amount='1',
            result='1',
            can_reject='0',
        )
        response = self.client.post(
            '/api/v1/public/payments/freedom/result',
            data=mismatch,
        )
        self.assertIn('<pg_status>ok</pg_status>', response.text)
        status_response = self.client.get(
            f"/api/v1/mobile/payments/{payment['paymentId']}",
            headers=headers,
        )
        self.assertEqual(status_response.json()['status'], 'pending')
        purchases_response = self.client.get(
            '/api/v1/mobile/tickets/purchases',
            headers=headers,
        )
        self.assertEqual(purchases_response.json()['total'], 0)
        with self.SessionLocal() as session:
            callback = session.scalar(select(MobilePaymentCallback))
            self.assertIsNotNone(callback)
            self.assertEqual(callback.result, 'reconciliation_required')

    def test_invalid_amount_and_currency_do_not_change_payment_state(self) -> None:
        auth = self._authenticate_mobile_user('+77071234567')
        headers = {'Authorization': f"Bearer {auth['access_token']}"}
        payment = self._init_payment(headers, 'checkout-invalid-callback')
        invalid_amount = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id=payment['externalPaymentId'],
            amount='1',
            result='1',
        )
        self.client.post('/api/v1/public/payments/freedom/result', data=invalid_amount)
        invalid_currency = self._signed_callback_payload(
            order_id=payment['localOrderId'],
            payment_id=payment['externalPaymentId'],
            amount='2700',
            currency='USD',
            result='1',
        )
        self.client.post('/api/v1/public/payments/freedom/result', data=invalid_currency)

        status_response = self.client.get(
            f"/api/v1/mobile/payments/{payment['paymentId']}",
            headers=headers,
        )
        self.assertEqual(status_response.json()['status'], 'pending')

    def _init_payment(
        self,
        headers: dict[str, str],
        idempotency_key: str,
    ) -> dict[str, object]:
        response = self.client.post(
            '/api/v1/mobile/payments/freedom/init',
            headers=headers,
            json={
                'idempotencyKey': idempotency_key,
                'ticketItems': [{'ticketItemId': 'ticket-kids', 'quantity': 1}],
            },
        )
        self.assertEqual(response.status_code, 200)
        return response.json()

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
        currency: str = 'KZT',
        can_reject: str = '1',
    ) -> dict[str, str]:
        payload = {
            'pg_order_id': order_id,
            'pg_payment_id': payment_id,
            'pg_amount': amount,
            'pg_currency': currency,
            'pg_result': result,
            'pg_payment_date': '2026-04-13 10:00:00',
            'pg_can_reject': can_reject,
            'pg_salt': 'gateway-salt',
        }
        payload['pg_sig'] = build_freedompay_signature(
            script_name='result',
            params=payload,
            secret_key='test-secret',
        )
        return payload
