import logging

from ...core.config.settings import Settings
from ...core.config.settings import get_settings
from ...core.exceptions.http import DomainHTTPException
from ...core.rate_limit.service import RateLimitService, get_rate_limit_service
from ...core.exceptions.http import NotFoundException
from ...db.repositories.news_event_repository import NewsEventRepository
from ...db.repositories.news_repository import NewsRepository
from .schemas import MobileNewsItem
from .schemas import NewsEventType

logger = logging.getLogger(__name__)


class NewsService:
    def __init__(
        self,
        *,
        repository: NewsRepository | None = None,
        event_repository: NewsEventRepository | None = None,
        rate_limit_service: RateLimitService | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.repository = repository or NewsRepository()
        self.event_repository = event_repository or NewsEventRepository()
        self.rate_limit_service = rate_limit_service or get_rate_limit_service()
        self.settings = settings or get_settings()

    def list_news(
        self,
        *,
        limit: int = 10,
        offset: int = 0,
    ) -> list[MobileNewsItem]:
        items = self.repository.list_mobile(limit=limit, offset=offset)
        return [self._serialize(item) for item in items]

    def get_news(self, news_id: str) -> MobileNewsItem:
        item = self.repository.get_mobile_by_id(news_id)
        if item is None:
            raise NotFoundException(
                code='news_not_found',
                message='Новость не найдена.',
            )
        return self._serialize(item)

    def record_event(
        self,
        news_id: str,
        *,
        event_type: NewsEventType,
        actor_id: str,
        client_ip: str,
    ) -> None:
        if self.repository.get_mobile_by_id(news_id) is None:
            raise NotFoundException(
                code='news_not_found',
                message='Новость не найдена.',
            )
        self._enforce_event_rate_limit(
            actor_id=actor_id,
            client_ip=client_ip,
        )
        self.event_repository.create(
            news_id=news_id,
            event_type=event_type,
        )
        logger.info(
            'News event recorded: news_id=%s event_type=%s',
            news_id,
            event_type,
        )

    def _enforce_event_rate_limit(
        self,
        *,
        actor_id: str,
        client_ip: str,
    ) -> None:
        normalized_actor = actor_id.strip() or client_ip.strip() or 'anonymous'
        snapshot = self.rate_limit_service.consume(
            f'news_event:{normalized_actor}',
            limit=max(1, self.settings.news_event_rate_limit_per_minute),
            window_seconds=max(1, self.settings.news_event_rate_limit_window_seconds),
        )
        if not snapshot.allowed:
            raise DomainHTTPException(
                code='news_event_rate_limited',
                message='Слишком много событий по новости. Повторите позже.',
                status_code=429,
                details=[
                    {
                        'field': 'event_type',
                        'message': (
                            f'Повторите через {snapshot.retry_after_seconds} сек.'
                        ),
                    }
                ],
            )

    def _serialize(self, item) -> MobileNewsItem:
        return MobileNewsItem(
            id=item.id,
            title=item.title,
            image_url=item.image_url,
            description=item.description,
            created_at=item.created_at,
        )
