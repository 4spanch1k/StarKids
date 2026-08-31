from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING
from urllib.parse import urlparse

if TYPE_CHECKING:
    from .settings import Settings

logger = logging.getLogger(__name__)


class ProductionConfigurationError(RuntimeError):
    """Raised when production would start with an unsafe configuration."""


@dataclass(frozen=True)
class RuntimeConfigurationStatus:
    environment: str
    mock_payment_enabled: bool
    push_enabled: bool
    development_seed_enabled: bool


_INSECURE_JWT_SECRETS = frozenset(
    {'replace-me', 'change-me', 'changeme', 'secret', 'secret-key'}
)
_INSECURE_ADMIN_PASSWORDS = frozenset(
    {'ChangeMe123!', 'change-me', 'password', 'password123'}
)
_INSECURE_ADMIN_EMAILS = frozenset({'admin@starkids.kz'})
_PLACEHOLDER_HOSTS = frozenset({'example.com', 'example.org'})
_INSECURE_TICKET_QR_SECRETS = frozenset(
    {'replace-me', 'change-me', 'changeme', 'secret', 'secret-key'}
)


def validate_runtime_configuration(settings: Settings) -> RuntimeConfigurationStatus:
    """Validate process-level configuration before serving requests.

    Development and test environments intentionally retain local fixtures and mock
    OTP/payment behavior. Production is fail-fast: an unsafe process must not start.
    """

    status = RuntimeConfigurationStatus(
        environment=settings.normalized_app_env,
        mock_payment_enabled=settings.freedompay_mock_mode,
        push_enabled=settings.fcm_is_configured,
        development_seed_enabled=settings.development_seed_enabled,
    )
    if not settings.is_production:
        if settings.requires_explicit_jwt_secret and _is_unsafe_jwt_secret(
            settings.jwt_secret_key
        ):
            raise ProductionConfigurationError(
                'JWT_SECRET_KEY must be a unique value of at least 32 characters'
            )
        return status

    errors: list[str] = []
    if _is_unsafe_jwt_secret(settings.jwt_secret_key):
        errors.append('JWT_SECRET_KEY must be a unique value of at least 32 characters')
    if _is_unsafe_ticket_qr_secret(settings.ticket_qr_secret):
        errors.append('TICKET_QR_SECRET must be a unique value of at least 32 characters')

    admin_email = (settings.admin_seed_email or '').strip()
    admin_password = (settings.admin_seed_password or '').strip()
    if admin_email or admin_password:
        if not admin_email or not admin_password:
            errors.append('ADMIN_SEED_EMAIL and ADMIN_SEED_PASSWORD must be provided together')
        elif (
            admin_password.lower()
            in {value.lower() for value in _INSECURE_ADMIN_PASSWORDS}
            or admin_email.lower() in _INSECURE_ADMIN_EMAILS
        ):
            errors.append('ADMIN_SEED credentials use a known development default')

    if settings.freedompay_mock_mode:
        errors.append('FREEDOMPAY_MOCK_MODE must be false')
    if not settings.is_freedompay_configured:
        errors.append(
            'FreedomPay merchant, secret, base, result, success and failure settings are required'
        )

    if settings.otp_mock_mode:
        errors.append('OTP mock authentication is not allowed')

    if settings.database_url == settings.default_database_url:
        errors.append('DATABASE_URL must be explicitly configured for production')
    if any(_is_local_url(origin) for origin in settings.cors_origins_list):
        errors.append('BACKEND_CORS_ORIGINS must not contain localhost in production')
    if any(
        _is_local_url(url) or _is_placeholder_url(url)
        for url in (
            settings.freedompay_base_url,
            settings.freedompay_result_url,
            settings.freedompay_success_url,
            settings.freedompay_failure_url,
        )
        if url
    ):
        errors.append('FreedomPay URLs must not point to localhost in production')

    if errors:
        raise ProductionConfigurationError('; '.join(errors))
    return status


def log_runtime_configuration(status: RuntimeConfigurationStatus) -> None:
    """Log safe configuration facts without credentials or token values."""

    logger.info(
        'Runtime configuration: environment=%s mock_payment=%s push_enabled=%s '
        'development_seed=%s',
        status.environment,
        status.mock_payment_enabled,
        status.push_enabled,
        status.development_seed_enabled,
    )


def _is_local_url(value: str) -> bool:
    parsed = urlparse(value)
    host = (parsed.hostname or '').lower()
    return host in {'localhost', '127.0.0.1', '::1'}


def _is_unsafe_jwt_secret(value: str) -> bool:
    normalized = value.strip()
    return (
        not normalized
        or normalized.lower() in _INSECURE_JWT_SECRETS
        or len(normalized) < 32
    )


def _is_unsafe_ticket_qr_secret(value: str | None) -> bool:
    normalized = (value or '').strip()
    return (
        not normalized
        or normalized.lower() in _INSECURE_TICKET_QR_SECRETS
        or len(normalized) < 32
        or normalized.upper().startswith(('PLACEHOLDER', 'REPLACE_ME', 'YOUR_'))
    )


def _is_placeholder_url(value: str) -> bool:
    parsed = urlparse(value)
    return (parsed.hostname or '').lower() in _PLACEHOLDER_HOSTS
