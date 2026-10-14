from collections.abc import Sequence
from datetime import UTC, datetime

from sqlalchemy import delete, func, or_, select

from ..models.news import News
from .base import Repository


class NewsRepository(Repository):
    def list_admin(self) -> list[News]:
        statement = select(News).order_by(
            News.display_order.asc(),
            func.coalesce(News.publish_at, News.created_at).desc(),
            News.created_at.desc(),
            News.id.desc(),
        )
        return list(self.db.scalars(statement).all())

    def list_mobile(
        self,
        *,
        limit: int | None = None,
        offset: int = 0,
    ) -> list[News]:
        statement = self._build_mobile_statement()
        if offset > 0:
            statement = statement.offset(offset)
        if limit is not None:
            statement = statement.limit(limit)
        return list(self.db.scalars(statement).all())

    def get_by_id(self, news_id: str) -> News | None:
        return self.db.scalar(select(News).where(News.id == news_id))

    def get_mobile_by_id(self, news_id: str) -> News | None:
        statement = self._build_mobile_statement().where(News.id == news_id)
        return self.db.scalar(statement)

    def create(self, *, payload: dict[str, object]) -> News:
        news = News(**payload)
        self.db.add(news)
        self.db.commit()
        self.db.refresh(news)
        return news

    def save(self, news: News) -> News:
        self.db.add(news)
        self.db.commit()
        self.db.refresh(news)
        return news

    def delete(self, news: News) -> None:
        self.db.delete(news)
        self.db.commit()

    def delete_many(self, news_ids: Sequence[str]) -> None:
        if not news_ids:
            return
        self.db.execute(delete(News).where(News.id.in_(news_ids)))
        self.db.commit()

    def _build_mobile_statement(self):
        now = datetime.now(UTC)
        return (
            select(News)
            .where(News.is_active.is_(True))
            .where(or_(News.publish_at.is_(None), News.publish_at <= now))
            .order_by(
                News.display_order.asc(),
                func.coalesce(News.publish_at, News.created_at).desc(),
                News.created_at.desc(),
                News.id.desc(),
            )
        )
