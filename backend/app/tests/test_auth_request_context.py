import unittest

from app.core.config.settings import Settings
from app.core.config.validation import (
    ProductionConfigurationError,
    validate_runtime_configuration,
)
from app.modules.auth_security.dependencies import resolve_client_ip


class ClientIpResolverTests(unittest.TestCase):
    def test_no_forwarded_header_uses_peer(self) -> None:
        self.assertEqual(
            resolve_client_ip(
                immediate_peer='198.51.100.40',
                forwarded_for=None,
                trusted_proxy_networks=(),
            ),
            '198.51.100.40',
        )

    def test_untrusted_peer_ignores_forged_forwarded_header(self) -> None:
        self.assertEqual(
            resolve_client_ip(
                immediate_peer='198.51.100.40',
                forwarded_for='1.2.3.4',
                trusted_proxy_networks=(
                    Settings(app_env='test', trusted_proxy_cidrs='127.0.0.1/32')
                    .trusted_proxy_networks
                ),
            ),
            '198.51.100.40',
        )

    def test_trusted_proxy_uses_one_forwarded_ip(self) -> None:
        self.assertEqual(
            resolve_client_ip(
                immediate_peer='127.0.0.1',
                forwarded_for='203.0.113.50',
                trusted_proxy_networks=Settings(
                    app_env='test',
                    trusted_proxy_cidrs='127.0.0.1/32,::1/128',
                ).trusted_proxy_networks,
            ),
            '203.0.113.50',
        )

    def test_rightmost_untrusted_address_wins_over_forged_prefix(self) -> None:
        self.assertEqual(
            resolve_client_ip(
                immediate_peer='127.0.0.1',
                forwarded_for='1.2.3.4, 203.0.113.50',
                trusted_proxy_networks=Settings(
                    app_env='test', trusted_proxy_cidrs='127.0.0.1/32'
                ).trusted_proxy_networks,
            ),
            '203.0.113.50',
        )

    def test_multiple_trusted_proxies_are_skipped_right_to_left(self) -> None:
        self.assertEqual(
            resolve_client_ip(
                immediate_peer='127.0.0.1',
                forwarded_for='198.51.100.10, 10.20.0.5',
                trusted_proxy_networks=Settings(
                    app_env='test',
                    trusted_proxy_cidrs='127.0.0.1/32,10.20.0.0/16',
                ).trusted_proxy_networks,
            ),
            '198.51.100.10',
        )

    def test_malformed_forwarded_values_fall_back_to_peer(self) -> None:
        self.assertEqual(
            resolve_client_ip(
                immediate_peer='127.0.0.1',
                forwarded_for='garbage, 999.999.999.999',
                trusted_proxy_networks=Settings(
                    app_env='test', trusted_proxy_cidrs='127.0.0.1/32'
                ).trusted_proxy_networks,
            ),
            '127.0.0.1',
        )

    def test_ipv6_peer_and_forwarded_client_are_canonicalized(self) -> None:
        trusted = Settings(
            app_env='test', trusted_proxy_cidrs='::1/128'
        ).trusted_proxy_networks
        self.assertEqual(
            resolve_client_ip(
                immediate_peer='::1',
                forwarded_for='2001:db8:0:0:0:0:0:1',
                trusted_proxy_networks=trusted,
            ),
            '2001:db8::1',
        )
        self.assertEqual(
            resolve_client_ip(
                immediate_peer='2001:db8::2',
                forwarded_for='2001:db8::1',
                trusted_proxy_networks=trusted,
            ),
            '2001:db8::2',
        )

    def test_missing_peer_has_deterministic_fallback(self) -> None:
        self.assertEqual(
            resolve_client_ip(
                immediate_peer=None,
                forwarded_for='203.0.113.50',
                trusted_proxy_networks=Settings(
                    app_env='test', trusted_proxy_cidrs='127.0.0.1/32'
                ).trusted_proxy_networks,
            ),
            'unknown',
        )


class TrustedProxyConfigurationTests(unittest.TestCase):
    @staticmethod
    def _deployed_settings(**overrides: object) -> Settings:
        values: dict[str, object] = {
            'app_env': 'staging',
            'jwt_secret_key': 'p' * 48,
            'otp_mock_mode': False,
            'database_url': 'postgresql+psycopg://boom:secret@db.internal:5432/boom',
            'backend_cors_origins': 'https://ops-staging.boombala.kz',
            'freedompay_merchant_id': 'merchant',
            'freedompay_secret_key': 'secret',
            'freedompay_base_url': 'https://api.freedompay.kz',
            'freedompay_result_url': 'https://api-staging.boombala.kz/result',
            'freedompay_success_url': 'starkids://payments/success',
            'freedompay_failure_url': 'starkids://payments/failure',
            'ticket_qr_secret': 'q' * 48,
            'redis_url': 'redis://127.0.0.1:6379/0',
            'trusted_proxy_cidrs': '127.0.0.1/32,::1/128',
        }
        values.update(overrides)
        return Settings(**values)

    def test_valid_staging_and_production_proxy_configurations_pass(self) -> None:
        staging = self._deployed_settings()
        self.assertEqual(validate_runtime_configuration(staging).environment, 'staging')
        production = self._deployed_settings(
            app_env='production',
            freedompay_testing_mode=False,
            backend_cors_origins='https://ops.boombala.kz',
            freedompay_result_url='https://api.boombala.kz/result',
        )
        self.assertEqual(
            validate_runtime_configuration(production).environment,
            'production',
        )

    def test_deployed_proxy_config_is_required_and_well_formed(self) -> None:
        for value in ('', 'not-an-ip-network', '127.0.0.1/999', '0.0.0.0/0'):
            with self.subTest(value=value), self.assertRaises(
                ProductionConfigurationError
            ):
                validate_runtime_configuration(
                    self._deployed_settings(trusted_proxy_cidrs=value)
                )

    def test_development_and_test_allow_empty_proxy_config(self) -> None:
        for app_env in ('development', 'test'):
            settings = Settings(app_env=app_env, trusted_proxy_cidrs='')
            self.assertEqual(
                validate_runtime_configuration(settings).environment,
                app_env,
            )

    def test_development_and_test_reject_malformed_proxy_config(self) -> None:
        for app_env in ('development', 'test'):
            with self.subTest(app_env=app_env), self.assertRaises(
                ProductionConfigurationError
            ):
                validate_runtime_configuration(
                    Settings(app_env=app_env, trusted_proxy_cidrs='garbage')
                )
