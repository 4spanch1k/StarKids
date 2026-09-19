from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import delete, func, or_, select

from ..models.mobile_notification import MobileNotification
from .base import Repository


class MobileNotificationRepository(Repository):
    def list_mobile(
        self,
        *,
        limit: int | None = None,
        offset: int = 0,
    ) -> list[MobileNotification]:
        statement = self._build_mobile_statement()
        if offset > 0:
            statement = statement.offset(offset)
        if limit is not None:
            statement = statement.limit(limit)
        return list(self.db.scalars(statement).all())

    def get_by_news_id(self, news_id: str) -> MobileNotification | None:
        statement = select(MobileNotification).where(
            MobileNotification.news_id == news_id,
        )
        return self.db.scalar(statement)

    def create(self, *, payload: dict[str, object]) -> MobileNotification:
        notification = MobileNotification(**payload)
        self.db.add(notification)
        self.db.commit()
        self.db.refresh(notification)
        return notification

    def save(self, notification: MobileNotification) -> MobileNotification:
        self.db.add(notification)
        self.db.commit()
        self.db.refresh(notification)
        return notification

    def delete(self, notification: MobileNotification) -> None:
        self.db.delete(notification)
        self.db.commit()

    def delete_by_news_id(self, news_id: str) -> None:
        self.db.execute(
            delete(MobileNotification).where(MobileNotification.news_id == news_id),
        )
        self.db.commit()

    def _build_mobile_statement(self):
        now = datetime.now(UTC)
        return (
            select(MobileNotification)
            .where(MobileNotification.is_active.is_(True))
            .where(
                or_(
                    MobileNotification.publish_at.is_(None),
                    MobileNotification.publish_at <= now,
                )
            )
            .order_by(
                func.coalesce(
                    MobileNotification.publish_at,
                    MobileNotification.created_at,
                ).desc(),
                MobileNotification.created_at.desc(),
                MobileNotification.id.desc(),
            )
        )
