import unittest

from app.core.config.settings import Settings
from app.core.exceptions.http import DomainHTTPException
from app.modules.admin_auth.schemas import AdminLoginRequest
from app.modules.admin_auth.service import AdminAuthService


class AdminAuthConfigurationTests(unittest.TestCase):
    def test_development_environment_keeps_local_bootstrap_defaults(self) -> None:
        settings = Settings(app_env='development')

        self.assertTrue(settings.is_development)
        self.assertEqual(settings.bootstrap_admin_email, 'admin@starkids.local')
        self.assertEqual(settings.bootstrap_admin_password, 'ChangeMe123!')
        self.assertFalse(settings.requires_explicit_jwt_secret)

    def test_non_development_environment_disables_local_bootstrap_defaults(self) -> None:
        settings = Settings(app_env='staging', jwt_secret_key='replace-me')

        self.assertFalse(settings.is_development)
        self.assertIsNone(settings.bootstrap_admin_email)
        self.assertIsNone(settings.bootstrap_admin_password)
        self.assertTrue(settings.requires_explicit_jwt_secret)

    def test_non_development_environment_rejects_placeholder_jwt_secret(self) -> None:
        service = AdminAuthService(
            settings=Settings(app_env='staging', jwt_secret_key='replace-me')
        )

        with self.assertRaises(DomainHTTPException) as context:
            service.login(
                AdminLoginRequest(
                    email='admin@starkids.kz',
                    password='StrongPass123!',
                )
            )

        self.assertEqual(context.exception.status_code, 503)
        self.assertEqual(context.exception.code, 'auth_configuration_error')
