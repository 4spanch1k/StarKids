from __future__ import annotations

from datetime import UTC, datetime, timedelta

from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from ...core.config.settings import Settings, get_settings
from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...core.storage.backend import StorageBackend
from ...db.models.news import News
from ...db.repositories.mobile_notification_repository import (
    MobileNotificationRepository,
)
from ...db.repositories.news_event_repository import (
    NewsEventRepository,
    NewsTopStatsSnapshot,
)
from ...db.repositories.news_repository import NewsRepository
from .schemas import (
    AdminNewsCreateRequest,
    AdminNewsImageUploadResponse,
    AdminNewsResponse,
    AdminNewsStatsResponse,
    AdminNewsTopStatsItem,
    AdminNewsTopStatsResponse,
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
        notification_repository: MobileNotificationRepository | None = None,
        event_repository: NewsEventRepository | None = None,
        storage: StorageBackend | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.repository = repository or NewsRepository()
        self.notification_repository = (
            notification_repository or MobileNotificationRepository()
        )
        self.event_repository = event_repository or NewsEventRepository()
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
                'title': payload.title,
                'image_url': payload.image_url,
                'description': payload.description,
                'is_active': payload.is_active,
                'display_order': payload.display_order,
                'publish_at': payload.publish_at,
            }
        )
        self._sync_news_notification(item)
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
            item.title = str(changes['title'])
        if 'image_url' in changes and changes['image_url'] is not None:
            item.image_url = str(changes['image_url'])
        if 'description' in changes:
            item.description = self._normalize_optional_text(changes['description'])
        if 'is_active' in changes:
            item.is_active = bool(changes['is_active'])
        if 'display_order' in changes and changes['display_order'] is not None:
            item.display_order = int(changes['display_order'])
        if 'publish_at' in changes:
            item.publish_at = self._normalize_datetime(changes['publish_at'])

        saved = self.repository.save(item)
        self._sync_news_notification(saved)
        return self._serialize(saved)

    def delete_news(self, news_id: str) -> None:
        item = self._get_news_or_404(news_id)
        storage_key = self._extract_storage_key(item.image_url)
        self.repository.delete(item)
        self.notification_repository.delete_by_news_id(news_id)
        if storage_key is not None:
            self._require_storage().delete(storage_key)

    def get_news_stats(self, news_id: str) -> AdminNewsStatsResponse:
        self._get_news_or_404(news_id)
        snapshot = self.event_repository.get_stats(news_id=news_id)
        return AdminNewsStatsResponse(
            views_count=snapshot.views_count,
            clicks_count=snapshot.clicks_count,
            ctr=self._calculate_ctr(snapshot.clicks_count, snapshot.views_count),
        )

    def get_top_stats(self, *, limit: int = 5) -> AdminNewsTopStatsResponse:
        now = datetime.now(UTC)
        return AdminNewsTopStatsResponse(
            last_24_hours=self._serialize_top_stats(
                self.event_repository.list_top_news_stats(
                    since=now - timedelta(hours=24),
                    limit=limit,
                )
            ),
            last_7_days=self._serialize_top_stats(
                self.event_repository.list_top_news_stats(
                    since=now - timedelta(days=7),
                    limit=limit,
                )
            ),
        )

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
            display_order=item.display_order,
            publish_at=item.publish_at,
            created_at=item.created_at,
        )

    def _normalize_optional_text(self, value: object) -> str | None:
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None

    def _normalize_datetime(self, value: object) -> datetime | None:
        if value is None:
            return None
        if isinstance(value, datetime):
            if value.tzinfo is not None:
                return value.astimezone(UTC)
            return value.replace(tzinfo=UTC)
        raise ValueError('Expected datetime value.')

    def _sync_news_notification(self, news: News) -> None:
        notification = self.notification_repository.get_by_news_id(news.id)
        payload = {
            'id': news.id,
            'news_id': news.id,
            'notification_type': 'news',
            'title': news.title,
            'description': news.description,
            'image_url': news.image_url,
            'is_active': news.is_active,
            'publish_at': news.publish_at,
        }

        if notification is None:
            self.notification_repository.create(payload=payload)
            return

        notification.title = news.title
        notification.description = news.description
        notification.image_url = news.image_url
        notification.is_active = news.is_active
        notification.publish_at = news.publish_at
        self.notification_repository.save(notification)

    def _serialize_top_stats(
        self,
        items: list[NewsTopStatsSnapshot],
    ) -> list[AdminNewsTopStatsItem]:
        return [
            AdminNewsTopStatsItem(
                news_id=item.news_id,
                title=item.title,
                image_url=item.image_url,
                views_count=item.views_count,
                clicks_count=item.clicks_count,
                ctr=self._calculate_ctr(item.clicks_count, item.views_count),
            )
            for item in items
        ]

    @staticmethod
    def _calculate_ctr(clicks_count: int, views_count: int) -> float:
        if views_count <= 0:
            return 0.0
        return round(clicks_count / views_count, 4)

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
