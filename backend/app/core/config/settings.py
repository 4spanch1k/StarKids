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


@lru_cache
def get_settings() -> Settings:
    return Settings()

