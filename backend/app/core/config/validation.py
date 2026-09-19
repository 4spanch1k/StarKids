from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING
from urllib.parse import urlparse

from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError

from ..storage.backend import SUPPORTED_STORAGE_BACKENDS

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
_SUPPORTED_PRODUCTION_DATABASE_DRIVERS = frozenset({'postgresql+psycopg'})


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
    storage_error = _storage_configuration_error(settings)
    if storage_error:
        raise ProductionConfigurationError(storage_error)

    # Settings validates the allowlist at construction time.  Keep the
    # explicit branches here as a defense in depth for callers that mutate a
    # Settings instance after construction.
    if settings.is_development or settings.is_test:
        if settings.requires_explicit_jwt_secret and _is_unsafe_jwt_secret(
            settings.jwt_secret_key
        ):
            raise ProductionConfigurationError(
                'JWT_SECRET_KEY must be a unique value of at least 32 characters'
            )
        return status

    if not (settings.is_production or settings.is_staging):
        raise ProductionConfigurationError(
            'APP_ENV must be one of: development, test, staging, production'
        )

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
    if settings.is_production and settings.freedompay_testing_mode:
        errors.append('FREEDOMPAY_TESTING_MODE must be false')
    if not settings.is_freedompay_configured:
        errors.append(
            'FreedomPay merchant, secret, base, result, success and failure settings are required'
        )

    if settings.otp_mock_mode:
        errors.append('OTP mock authentication is not allowed')

    if _is_default_database_url(settings.database_url, settings.default_database_url):
        errors.append('DATABASE_URL must be explicitly configured for production')
    database_error = _production_database_configuration_error(settings.database_url)
    if database_error:
        errors.append(database_error)
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


def _storage_configuration_error(settings: Settings) -> str | None:
    backend = (settings.storage_backend or '').lower()
    if backend not in SUPPORTED_STORAGE_BACKENDS:
        return 'STORAGE_BACKEND must be one of: local, s3'
    if backend == 's3' and not (settings.s3_bucket or '').strip():
        return 'S3_BUCKET is required when STORAGE_BACKEND=s3'
    return None


def _production_database_configuration_error(database_url: str) -> str | None:
    """Return a safe error for unsupported production SQLAlchemy URLs.

    The project installs only the psycopg 3 driver, so the explicit
    ``postgresql+psycopg`` URL is the sole production driver that the engine
    can construct.  Parsing is performed without logging or interpolating the
    URL, which keeps credentials out of configuration errors.
    """

    if not isinstance(database_url, str) or not database_url.strip():
        return 'DATABASE_URL must use PostgreSQL with the psycopg driver in production'
    try:
        parsed = make_url(database_url)
        port = parsed.port
    except (ArgumentError, TypeError, ValueError):
        return 'DATABASE_URL must be a valid PostgreSQL URL in production'
    if parsed.drivername not in _SUPPORTED_PRODUCTION_DATABASE_DRIVERS:
        return 'DATABASE_URL must use PostgreSQL with the psycopg driver in production'
    if not parsed.host or not parsed.database:
        return 'DATABASE_URL must include a PostgreSQL host and database in production'
    if port is not None and not 1 <= port <= 65535:
        return 'DATABASE_URL must be a valid PostgreSQL URL in production'
    return None


def _is_default_database_url(database_url: str, default_database_url: str) -> bool:
    """Compare the configured database identity without exposing credentials.

    Empty query parameters and an omitted PostgreSQL default port are equivalent
    spellings of the local development URL and must not bypass the production
    default guard.
    """

    try:
        actual = make_url(database_url)
        default = make_url(default_database_url)
    except (ArgumentError, TypeError, ValueError):
        return False

    def identity(url):
        return (
            url.drivername,
            url.username,
            url.password,
            url.host,
            url.port or 5432,
            url.database,
        )

    try:
        return identity(actual) == identity(default)
    except (TypeError, ValueError):
        return False
