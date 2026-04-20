from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from ...core.config.settings import Settings, get_settings
from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...core.storage.backend import StorageBackend
from ...db.models.news import News
from ...db.repositories.news_repository import NewsRepository
from .schemas import (
    AdminNewsCreateRequest,
    AdminNewsImageUploadResponse,
    AdminNewsResponse,
    AdminNewsUpdateRequest,
)

NEWS_ADMIN_ALLOWED_ROLES = ('super_admin', 'content_manager')
_ALLOWED_IMAGE_TYPES = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
}


class AdminNewsService:
    def __init__(
        self,
        *,
        repository: NewsRepository | None = None,
        storage: StorageBackend | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.repository = repository or NewsRepository()
        self.storage = storage
        self.settings = settings or get_settings()

    def list_news(self) -> list[AdminNewsResponse]:
        return [self._serialize(item) for item in self.repository.list_admin()]

    def get_news(self, news_id: str) -> AdminNewsResponse:
        item = self._get_news_or_404(news_id)
        return self._serialize(item)

    def create_news(self, payload: AdminNewsCreateRequest) -> AdminNewsResponse:
        item = self.repository.create(
            payload={
                'title': payload.title.strip(),
                'image_url': payload.image_url.strip(),
                'description': self._normalize_optional_text(payload.description),
                'is_active': payload.is_active,
            }
        )
        return self._serialize(item)

    def update_news(
        self,
        news_id: str,
        payload: AdminNewsUpdateRequest,
    ) -> AdminNewsResponse:
        item = self._get_news_or_404(news_id)
        changes = payload.model_dump(exclude_unset=True)
        if not changes:
            return self._serialize(item)

        if 'title' in changes:
            item.title = str(changes['title']).strip()
        if 'image_url' in changes and changes['image_url'] is not None:
            item.image_url = str(changes['image_url']).strip()
        if 'description' in changes:
            item.description = self._normalize_optional_text(changes['description'])
        if 'is_active' in changes:
            item.is_active = bool(changes['is_active'])

        saved = self.repository.save(item)
        return self._serialize(saved)

    def delete_news(self, news_id: str) -> None:
        item = self._get_news_or_404(news_id)
        storage_key = self._extract_storage_key(item.image_url)
        self.repository.delete(item)
        if storage_key is not None:
            self._require_storage().delete(storage_key)

    async def upload_image(
        self,
        file: UploadFile,
        *,
        public_base_url: str,
    ) -> AdminNewsImageUploadResponse:
        content_type = (file.content_type or '').strip().lower()
        if content_type not in _ALLOWED_IMAGE_TYPES:
            raise DomainHTTPException(
                code='invalid_news_image',
                message='Поддерживаются только JPEG, PNG и WebP изображения.',
                status_code=422,
                details=[{'field': 'file', 'message': 'Выберите JPG, PNG или WebP файл.'}],
            )

        content = await file.read()
        if not content:
            raise DomainHTTPException(
                code='invalid_news_image',
                message='Файл изображения пустой.',
                status_code=422,
                details=[{'field': 'file', 'message': 'Загрузите непустое изображение.'}],
            )
        if len(content) > self.settings.max_avatar_size_bytes:
            raise DomainHTTPException(
                code='invalid_news_image',
                message='Файл изображения слишком большой.',
                status_code=422,
                details=[{'field': 'file', 'message': 'Размер файла должен быть не больше 5 МБ.'}],
            )

        ext = _ALLOWED_IMAGE_TYPES[content_type]
        storage_key = f'news/{uuid4().hex}.{ext}'
        stored = self._require_storage().save(content, storage_key, content_type)
        image_url = self._normalize_public_url(stored.url, public_base_url=public_base_url)
        return AdminNewsImageUploadResponse(image_url=image_url)

    def _get_news_or_404(self, news_id: str) -> News:
        item = self.repository.get_by_id(news_id)
        if item is None:
            raise NotFoundException(
                code='news_not_found',
                message='Новость не найдена.',
            )
        return item

    def _serialize(self, item: News) -> AdminNewsResponse:
        return AdminNewsResponse(
            id=item.id,
            title=item.title,
            image_url=item.image_url,
            description=item.description,
            is_active=item.is_active,
            created_at=item.created_at,
        )

    def _normalize_optional_text(self, value: object) -> str | None:
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None

    def _normalize_public_url(
        self,
        value: str,
        *,
        public_base_url: str,
    ) -> str:
        normalized = value.strip()
        if normalized.startswith('http://') or normalized.startswith('https://'):
            return normalized
        return f'{public_base_url.rstrip("/")}{normalized}'

    def _extract_storage_key(self, url: str) -> str | None:
        normalized = url.strip()
        if not normalized:
            return None

        media_prefix = self.settings.normalized_media_url_prefix + '/'
        if normalized.startswith(media_prefix):
            return normalized[len(media_prefix):]

        public_base_url = (self.settings.public_base_url or '').rstrip('/')
        if public_base_url:
            full_prefix = f'{public_base_url}{media_prefix}'
            if normalized.startswith(full_prefix):
                return normalized[len(full_prefix):]

        path = Path(normalized).as_posix()
        marker = f'{media_prefix}'
        if marker in path:
            return path.split(marker, maxsplit=1)[1]
        return None

    def _require_storage(self) -> StorageBackend:
        if self.storage is None:
            raise RuntimeError('News storage backend is not configured.')
        return self.storage
