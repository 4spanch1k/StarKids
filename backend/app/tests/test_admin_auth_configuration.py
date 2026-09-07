import unittest

from pydantic import ValidationError

from app.core.config.settings import Settings


class AdminAuthConfigurationTests(unittest.TestCase):
    def test_development_environment_keeps_local_bootstrap_defaults(self) -> None:
        settings = Settings(app_env='development')

        self.assertTrue(settings.is_development)
        self.assertEqual(settings.bootstrap_admin_email, 'admin@starkids.kz')
        self.assertEqual(settings.bootstrap_admin_password, 'ChangeMe123!')
        self.assertFalse(settings.requires_explicit_jwt_secret)

    def test_unknown_environment_is_rejected_before_auth(self) -> None:
        with self.assertRaises(ValidationError):
            Settings(app_env='staging', jwt_secret_key='replace-me')
