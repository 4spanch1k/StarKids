from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .api.router import api_router
from .core.config.settings import get_settings
from .core.exceptions.handlers import register_exception_handlers
from .core.logging.setup import configure_logging

configure_logging()
settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version='0.1.0',
    docs_url='/docs',
    redoc_url='/redoc',
)
register_exception_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

app.include_router(api_router, prefix='/api/v1')

if settings.storage_backend.lower() == 'local':
    media_root = Path(settings.media_root)
    media_root.mkdir(parents=True, exist_ok=True)
    app.mount(
        settings.normalized_media_url_prefix,
        StaticFiles(directory=media_root),
        name='media',
    )


@app.get('/healthz', tags=['health'])
def healthcheck() -> dict[str, str]:
    return {'status': 'ok'}
