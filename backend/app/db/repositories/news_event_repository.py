from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import case, func, select

from ..models.news import News
from ..models.news_event import NewsEvent
from .base import Repository


@dataclass(frozen=True)
class NewsEventStatsSnapshot:
    views_count: int
    clicks_count: int


@dataclass(frozen=True)
class NewsTopStatsSnapshot:
    news_id: str
    title: str
    image_url: str
    views_count: int
    clicks_count: int


class NewsEventRepository(Repository):
    def create(
        self,
        *,
        news_id: str,
        event_type: str,
    ) -> NewsEvent:
        event = NewsEvent(
            news_id=news_id,
            event_type=event_type,
        )
        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)
        return event

    def get_stats(
        self,
        *,
        news_id: str,
        since: datetime | None = None,
    ) -> NewsEventStatsSnapshot:
        conditions = [NewsEvent.news_id == news_id]
        if since is not None:
            conditions.append(NewsEvent.created_at >= self._normalize_datetime(since))

        statement = select(
            func.coalesce(
                func.sum(
                    case((NewsEvent.event_type == 'view', 1), else_=0),
                ),
                0,
            ),
            func.coalesce(
                func.sum(
                    case((NewsEvent.event_type == 'click', 1), else_=0),
                ),
                0,
            ),
        ).where(*conditions)

        row = self.db.execute(statement).one()
        return NewsEventStatsSnapshot(
            views_count=int(row[0] or 0),
            clicks_count=int(row[1] or 0),
        )

    def list_top_news_stats(
        self,
        *,
        since: datetime,
        limit: int = 5,
    ) -> list[NewsTopStatsSnapshot]:
        normalized_since = self._normalize_datetime(since)
        views_count = func.coalesce(
            func.sum(case((NewsEvent.event_type == 'view', 1), else_=0)),
            0,
        )
        clicks_count = func.coalesce(
            func.sum(case((NewsEvent.event_type == 'click', 1), else_=0)),
            0,
        )

        statement = (
            select(
                News.id,
                News.title,
                News.image_url,
                views_count.label('views_count'),
                clicks_count.label('clicks_count'),
            )
            .join(NewsEvent, NewsEvent.news_id == News.id)
            .where(NewsEvent.created_at >= normalized_since)
            .group_by(News.id, News.title, News.image_url, News.created_at)
            .order_by(
                views_count.desc(),
                clicks_count.desc(),
                News.created_at.desc(),
                News.id.desc(),
            )
            .limit(limit)
        )

        rows = self.db.execute(statement).all()
        return [
            NewsTopStatsSnapshot(
                news_id=str(row[0]),
                title=str(row[1]),
                image_url=str(row[2]),
                views_count=int(row[3] or 0),
                clicks_count=int(row[4] or 0),
            )
            for row in rows
        ]

    @staticmethod
    def _normalize_datetime(value: datetime) -> datetime:
        if value.tzinfo is not None:
            return value.astimezone(UTC)
        return value.replace(tzinfo=UTC)
