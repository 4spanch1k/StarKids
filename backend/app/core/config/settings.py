from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = 'Star Kids API'
    app_env: str = 'development'
    backend_host: str = '0.0.0.0'
    backend_port: int = 8000
    backend_cors_origins: str = 'http://localhost:5173'
    database_url: str = (
        'postgresql+psycopg://postgres:postgres@localhost:5432/star_kids'
    )
    jwt_secret_key: str = 'replace-me'
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
    admin_seed_full_name: str = 'Star Kids Admin'
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

    fcm_project_id: str | None = None
    fcm_client_email: str | None = None
    fcm_private_key: str | None = None

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
        return bool(self.fcm_project_id and self.fcm_client_email and self.fcm_private_key)

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
        return self.app_env.strip().lower()

    @property
    def is_development(self) -> bool:
        return self.normalized_app_env == 'development'

    @property
    def requires_explicit_jwt_secret(self) -> bool:
        return not self.is_development

    @property
    def bootstrap_admin_email(self) -> str | None:
        if self.admin_seed_email:
            return self.admin_seed_email
        if self.is_development:
            return 'admin@starkids.kz'
        return None

    @property
    def bootstrap_admin_password(self) -> str | None:
        if self.admin_seed_password:
            return self.admin_seed_password
        if self.is_development:
            return 'ChangeMe123!'
        return None

    @property
    def is_freedompay_configured(self) -> bool:
        return all(
            (
                self.freedompay_merchant_id,
                self.freedompay_secret_key,
                self.freedompay_base_url,
                self.freedompay_result_url,
                self.freedompay_success_url,
                self.freedompay_failure_url,
            )
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
