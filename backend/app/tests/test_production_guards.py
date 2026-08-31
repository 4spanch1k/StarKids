import logging
import unittest
from unittest.mock import Mock

from app.core.config.settings import Settings
from app.core.config.validation import (
    ProductionConfigurationError,
    RuntimeConfigurationStatus,
    log_runtime_configuration,
    validate_runtime_configuration,
)
from app.modules.admin_branches.service import AdminBranchService
from app.modules.branches.service import BranchService
from app.modules.mobile_auth.schemas import OTPRequest, OTPVerifyRequest
from app.modules.mobile_auth.service import MobileAuthService
from app.modules.mobile_payments.freedompay_client import (
    FreedomPayClient,
    FreedomPayGatewayError,
)
from app.core.exceptions.http import DomainHTTPException


def production_settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        'app_env': 'production',
        'jwt_secret_key': 'p' * 48,
        'otp_mock_mode': False,
        'database_url': 'postgresql+psycopg://boom:secret@db.internal:5432/boom',
        'backend_cors_origins': 'https://app.boombala.kz',
        'freedompay_merchant_id': 'merchant',
        'freedompay_secret_key': 'secret',
        'freedompay_base_url': 'https://api.freedompay.kz',
        'freedompay_result_url': 'https://api.boombala.kz/payments/result',
        'freedompay_success_url': 'https://app.boombala.kz/payment/success',
        'freedompay_failure_url': 'https://app.boombala.kz/payment/failure',
        'ticket_qr_secret': 'q' * 48,
    }
    values.update(overrides)
    return Settings(**values)


class ProductionGuardTests(unittest.TestCase):
    def test_production_rejects_default_jwt_secret(self) -> None:
        with self.assertRaises(ProductionConfigurationError):
            validate_runtime_configuration(
                production_settings(jwt_secret_key='replace-me')
            )

    def test_production_requires_strong_ticket_qr_secret(self) -> None:
        for value in (None, 'replace-me', 'short'):
            with self.subTest(value=value), self.assertRaises(
                ProductionConfigurationError
            ):
                validate_runtime_configuration(
                    production_settings(ticket_qr_secret=value)
                )

    def test_production_rejects_default_admin_bootstrap_credentials(self) -> None:
        with self.assertRaises(ProductionConfigurationError):
            validate_runtime_configuration(
                production_settings(
                    admin_seed_email='admin@starkids.kz',
                    admin_seed_password='ChangeMe123!',
                )
            )

    def test_production_allows_explicit_non_default_admin_bootstrap(self) -> None:
        status = validate_runtime_configuration(
            production_settings(
                admin_seed_email='ops@boombala.kz',
                admin_seed_password='A-strong-production-password-42',
            )
        )
        self.assertEqual(status.environment, 'production')

    def test_production_rejects_freedompay_mock_and_missing_credentials(self) -> None:
        with self.assertRaises(ProductionConfigurationError):
            validate_runtime_configuration(
                production_settings(freedompay_mock_mode=True)
            )
        with self.assertRaises(ProductionConfigurationError):
            validate_runtime_configuration(
                production_settings(freedompay_secret_key=None)
            )

    def test_placeholder_firebase_values_are_reported_as_disabled(self) -> None:
        settings = Settings(
            fcm_project_id='PLACEHOLDER_PROJECT_ID',
            fcm_client_email='placeholder@example.com',
            fcm_private_key='PLACEHOLDER_PRIVATE_KEY',
        )
        self.assertFalse(settings.fcm_is_configured)
        status = validate_runtime_configuration(settings)
        self.assertFalse(status.push_enabled)

    def test_production_freedompay_client_cannot_reach_mock_url(self) -> None:
        settings = production_settings(freedompay_mock_mode=True)
        with self.assertRaises(FreedomPayGatewayError):
            FreedomPayClient(settings).init_payment({'pg_order_id': 'order-1'})

    def test_production_rejects_local_database_and_cors_defaults(self) -> None:
        with self.assertRaises(ProductionConfigurationError):
            validate_runtime_configuration(
                production_settings(
                    database_url=Settings().default_database_url,
                    backend_cors_origins='http://localhost:5173',
                )
            )

    def test_production_otp_placeholder_is_unavailable(self) -> None:
        service = MobileAuthService(settings=production_settings())

        with self.assertRaises(DomainHTTPException) as request_context:
            service.request_otp(OTPRequest(phone='+77070000000'))
        self.assertEqual(request_context.exception.code, 'otp_not_configured')
        self.assertEqual(request_context.exception.status_code, 503)

        with self.assertRaises(DomainHTTPException) as verify_context:
            service.verify_otp(
                OTPVerifyRequest(
                    phone='+77070000000',
                    code='1234',
                    verification_id='otp_arbitrary',
                )
            )
        self.assertEqual(verify_context.exception.code, 'otp_not_configured')

    def test_production_branch_reads_never_seed_menu_or_tickets(self) -> None:
        menu_repository = Mock()
        menu_repository.has_menu.return_value = False
        ticket_repository = Mock()
        ticket_repository.has_ticket_config.return_value = False
        service = BranchService(
            menu_repository=menu_repository,
            ticket_repository=ticket_repository,
            settings=production_settings(),
        )

        service._ensure_branch_menu_seeded('branch-1')
        service._ensure_branch_tickets_seeded('branch-1')

        menu_repository.replace_branch_menu.assert_not_called()
        ticket_repository.replace_branch_ticket_config.assert_not_called()

    def test_development_branch_reads_keep_local_seed_support(self) -> None:
        menu_repository = Mock()
        menu_repository.has_menu.return_value = False
        ticket_repository = Mock()
        ticket_repository.has_ticket_config.return_value = False
        service = BranchService(
            menu_repository=menu_repository,
            ticket_repository=ticket_repository,
            settings=Settings(app_env='development'),
        )

        service._ensure_branch_menu_seeded('branch-1')
        service._ensure_branch_tickets_seeded('branch-1')

        menu_repository.replace_branch_menu.assert_called_once()
        ticket_repository.replace_branch_ticket_config.assert_called_once()

    def test_production_admin_reads_never_seed_menu_or_tickets(self) -> None:
        menu_repository = Mock()
        menu_repository.has_menu.return_value = False
        ticket_repository = Mock()
        ticket_repository.has_ticket_config.return_value = False
        service = AdminBranchService(
            menu_repository=menu_repository,
            ticket_repository=ticket_repository,
            settings=production_settings(),
        )

        service._ensure_branch_menu_seeded('branch-1')
        service._ensure_branch_tickets_seeded('branch-1')

        menu_repository.replace_branch_menu.assert_not_called()
        ticket_repository.replace_branch_ticket_config.assert_not_called()

    def test_runtime_log_contains_only_non_secret_configuration(self) -> None:
        status = RuntimeConfigurationStatus(
            environment='production',
            mock_payment_enabled=False,
            push_enabled=False,
            development_seed_enabled=False,
        )
        with self.assertLogs('app.core.config.validation', level=logging.INFO) as logs:
            log_runtime_configuration(status)
        message = '\n'.join(logs.output)
        self.assertIn('environment=production', message)
        self.assertNotIn('secret', message.lower())
        self.assertNotIn('password', message.lower())
        self.assertNotIn('token', message.lower())
