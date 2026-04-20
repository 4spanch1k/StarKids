from collections.abc import Sequence

from sqlalchemy import delete, select

from ..models.news import News
from .base import Repository


class NewsRepository(Repository):
    def list_admin(self) -> list[News]:
        statement = select(News).order_by(News.created_at.desc(), News.id.desc())
        return list(self.db.scalars(statement).all())

    def list_mobile(self) -> list[News]:
        statement = (
            select(News)
            .where(News.is_active.is_(True))
            .order_by(News.created_at.desc(), News.id.desc())
        )
        return list(self.db.scalars(statement).all())

    def get_by_id(self, news_id: str) -> News | None:
        return self.db.scalar(select(News).where(News.id == news_id))

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
