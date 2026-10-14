from decimal import Decimal
import unittest

from app.core.config.settings import Settings
from app.modules.mobile_payments.kaspi import (
    KaspiProtocolError,
    build_kaspi_payment_url,
    is_kaspi_source_allowed,
    parse_kaspi_amount,
)


class KaspiPaymentHelperTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settings = Settings(
            app_env='test',
            kaspi_service_name='boom-bala',
            kaspi_service_id='service-42',
            kaspi_account_parameter_id='account',
        )

    def test_checkout_url_uses_persisted_order_and_fixed_amount(self) -> None:
        url = build_kaspi_payment_url(
            settings=self.settings,
            local_order_id='sk-order-42',
            cash_amount_tenge=2700,
        )
        self.assertIn('https://kaspi.kz/pay/boom-bala?', url)
        self.assertIn('service_id=service-42', url)
        self.assertIn('account=sk-order-42', url)
        self.assertIn('amount=2700.00', url)

    def test_amount_is_decimal_and_invalid_values_fail_closed(self) -> None:
        self.assertEqual(parse_kaspi_amount('2700.00'), Decimal('2700.00'))
        with self.assertRaises(KaspiProtocolError):
            parse_kaspi_amount('not-a-number')
        with self.assertRaises(KaspiProtocolError):
            parse_kaspi_amount('-1')

    def test_source_allowlist_does_not_trust_arbitrary_ip(self) -> None:
        networks = (Settings(app_env='test').trusted_proxy_networks or ())
        self.assertFalse(is_kaspi_source_allowed('203.0.113.10', networks))

