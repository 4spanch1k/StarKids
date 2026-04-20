from ...db.repositories.news_repository import NewsRepository
from .schemas import MobileNewsItem


class NewsService:
    def __init__(
        self,
        *,
        repository: NewsRepository | None = None,
    ) -> None:
        self.repository = repository or NewsRepository()

    def list_news(self) -> list[MobileNewsItem]:
        items = self.repository.list_mobile()
        return [
            MobileNewsItem(
                id=item.id,
                title=item.title,
                image_url=item.image_url,
                description=item.description,
                created_at=item.created_at,
            )
            for item in items
        ]
