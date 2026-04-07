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
    admin_seed_email: str | None = None
    admin_seed_password: str | None = None
    admin_seed_full_name: str = 'Star Kids Admin'
    admin_seed_role: str = 'super_admin'

    model_config = SettingsConfigDict(
        env_file='.env',
        env_file_encoding='utf-8',
        extra='ignore',
    )

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
            return 'admin@starkids.local'
        return None

    @property
    def bootstrap_admin_password(self) -> str | None:
        if self.admin_seed_password:
            return self.admin_seed_password
        if self.is_development:
            return 'ChangeMe123!'
        return None


@lru_cache
def get_settings() -> Settings:
    return Settings()
