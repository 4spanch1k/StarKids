from functools import lru_cache
from ipaddress import IPv4Network, IPv6Network, ip_network
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = 'Boom Bala API'
    # This value is intentionally required.  A missing or misspelled
    # environment must stop startup instead of silently enabling local auth
    # and bootstrap defaults.
    app_env: Literal['development', 'test', 'staging', 'production']
    backend_host: str = '0.0.0.0'
    backend_port: int = 8000
    trusted_proxy_cidrs: str = ''
    backend_cors_origins: str = 'http://localhost:5173'
    database_url: str = (
        'postgresql+psycopg://postgres:postgres@localhost:5432/star_kids'
    )
    jwt_secret_key: str = 'replace-me'
    otp_mock_mode: bool = True
    otp_code_ttl_seconds: int = Field(default=300, gt=0, le=3600)
    otp_max_attempts: int = Field(default=5, gt=0, le=20)
    otp_resend_cooldown_seconds: int = Field(default=60, gt=0, le=3600)
    otp_request_limit_per_phone: int = Field(default=5, gt=0, le=100)
    otp_request_limit_per_ip: int = Field(default=20, gt=0, le=500)
    otp_request_window_seconds: int = Field(default=3600, gt=0, le=86400)
    otp_verify_limit_per_ip_phone: int = Field(default=10, gt=0, le=100)
    otp_verify_window_seconds: int = Field(default=600, gt=0, le=86400)
    jwt_access_token_ttl_minutes: int = 30
    jwt_refresh_token_ttl_days: int = 14
    auth_password_min_length: int = 10
    auth_login_max_failures: int = 5
    auth_login_lockout_minutes: int = 10
    auth_login_captcha_after_failures: int = 3
    auth_captcha_ttl_minutes: int = 5
    redis_url: str | None = None
    redis_key_prefix: str = 'star_kids'
    news_event_rate_limit_per_minute: int = 20
    news_event_rate_limit_window_seconds: int = 60
    admin_seed_email: str | None = None
    admin_seed_password: str | None = None
    admin_seed_full_name: str = 'Boom Bala Admin'
    admin_seed_role: str = 'super_admin'
    freedompay_merchant_id: str | None = None
    freedompay_secret_key: str | None = None
    freedompay_base_url: str = 'https://api.freedompay.kz'
    freedompay_result_url: str | None = None
    freedompay_success_url: str | None = None
    freedompay_failure_url: str | None = None
    freedompay_testing_mode: bool = False
    freedompay_mock_mode: bool = False
    freedompay_request_timeout_seconds: int = 15
    ticket_qr_secret: str | None = None

    fcm_project_id: str | None = None
    fcm_client_email: str | None = None
    fcm_private_key: str | None = None
    push_notifications_enabled: bool = True
    birthday_reminders_enabled: bool = False
    birthday_reminder_windows: str = '30,14,7'
    birthday_reminder_30_title: str = 'Скоро день рождения 🎂'
    birthday_reminder_30_body: str = 'У вашего ребёнка скоро день рождения. Посмотрите варианты праздника в Boom Bala.'
    birthday_reminder_14_title: str = 'Скоро день рождения 🎉'
    birthday_reminder_14_body: str = 'Пора планировать праздник в Boom Bala'
    birthday_reminder_7_title: str = 'До праздника всё ближе 🎈'
    birthday_reminder_7_body: str = 'Посмотрите варианты праздника в Boom Bala'
    birthday_reminder_1_title: str = 'Завтра особенный день 🎉'
    birthday_reminder_1_body: str = 'Посмотрите, как можно отметить его в Boom Bala'

    clerk_secret_key: str | None = None
    clerk_issuer: str | None = None
    clerk_jwks_url: str | None = None
    clerk_authorized_parties: str | None = None

    storage_backend: str = 'local'
    media_root: str = './media'
    media_url_prefix: str = '/media'
    public_base_url: str | None = None
    max_avatar_size_bytes: int = 5 * 1024 * 1024
    s3_bucket: str | None = None
    s3_region: str | None = None
    s3_endpoint: str | None = None
    s3_access_key: str | None = None
    s3_secret_key: str | None = None
    s3_public_base_url: str | None = None

    model_config = SettingsConfigDict(
        env_file='.env',
        env_file_encoding='utf-8',
        extra='ignore',
    )

    @property
    def fcm_is_configured(self) -> bool:
        values = (self.fcm_project_id, self.fcm_client_email, self.fcm_private_key)
        return all(
            value
            and value.strip()
            and not value.strip().upper().startswith(
                ('PLACEHOLDER', 'REPLACE_ME', 'YOUR_')
            )
            for value in values
        )

    @property
    def clerk_authorized_parties_list(self) -> list[str]:
        if not self.clerk_authorized_parties:
            return []
        return [
            party.strip()
            for party in self.clerk_authorized_parties.split(',')
            if party.strip()
        ]

    @property
    def resolved_clerk_jwks_url(self) -> str | None:
        if self.clerk_jwks_url:
            return self.clerk_jwks_url
        if self.clerk_issuer:
            return f'{self.clerk_issuer.rstrip("/")}/.well-known/jwks.json'
        return None

    @property
    def normalized_media_url_prefix(self) -> str:
        return self.media_url_prefix.rstrip('/')

    @property
    def cors_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.backend_cors_origins.split(',')
            if origin.strip()
        ]

    @property
    def normalized_app_env(self) -> str:
        return self.app_env

    @property
    def trusted_proxy_networks(self) -> tuple[IPv4Network | IPv6Network, ...]:
        return parse_trusted_proxy_cidrs(self.trusted_proxy_cidrs)

    @property
    def is_development(self) -> bool:
        return self.normalized_app_env == 'development'

    @property
    def is_test(self) -> bool:
        return self.normalized_app_env == 'test'

    @property
    def is_production(self) -> bool:
        return self.normalized_app_env == 'production'

    @property
    def is_staging(self) -> bool:
        return self.normalized_app_env == 'staging'

    @property
    def development_seed_enabled(self) -> bool:
        return self.is_development or self.is_test

    @property
    def allows_mock_otp(self) -> bool:
        """Return whether local console-delivered OTP is explicitly allowed."""
        return self.otp_mock_mode and (self.is_development or self.is_test)

    @property
    def default_database_url(self) -> str:
        return 'postgresql+psycopg://postgres:postgres@localhost:5432/star_kids'

    @property
    def requires_explicit_jwt_secret(self) -> bool:
        return not self.development_seed_enabled

    @property
    def bootstrap_admin_email(self) -> str | None:
        if self.admin_seed_email:
            return self.admin_seed_email
        if self.development_seed_enabled:
            return 'admin@starkids.kz'
        return None

    @property
    def bootstrap_admin_password(self) -> str | None:
        if self.admin_seed_password:
            return self.admin_seed_password
        if self.development_seed_enabled:
            return 'ChangeMe123!'
        return None

    @property
    def is_freedompay_configured(self) -> bool:
        return all(
            (
                value and value.strip()
                for value in (
                    self.freedompay_merchant_id,
                    self.freedompay_secret_key,
                    self.freedompay_base_url,
                    self.freedompay_result_url,
                    self.freedompay_success_url,
                    self.freedompay_failure_url,
                )
            )
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


def parse_trusted_proxy_cidrs(
    value: str | None,
) -> tuple[IPv4Network | IPv6Network, ...]:
    """Parse the explicit proxy allowlist without trusting arbitrary headers."""
    raw = (value or '').strip()
    if not raw:
        return ()

    networks: list[IPv4Network | IPv6Network] = []
    for item in raw.split(','):
        candidate = item.strip()
        if not candidate:
            raise ValueError('TRUSTED_PROXY_CIDRS contains an empty entry')
        try:
            networks.append(ip_network(candidate, strict=False))
        except ValueError as exc:
            raise ValueError('TRUSTED_PROXY_CIDRS contains an invalid network') from exc
    return tuple(networks)
