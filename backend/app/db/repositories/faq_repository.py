from sqlalchemy import select

from ..models.faq_entry import FAQEntry
from .base import Repository


class FAQRepository(Repository):
    def list_admin(
        self,
        *,
        is_active: bool | None = None,
        is_published: bool | None = None,
    ) -> list[FAQEntry]:
        statement = select(FAQEntry)
        if is_active is not None:
            statement = statement.where(FAQEntry.is_active.is_(is_active))
        if is_published is not None:
            statement = statement.where(FAQEntry.is_published.is_(is_published))
        statement = statement.order_by(FAQEntry.display_order.asc(), FAQEntry.question.asc())
        return list(self.db.scalars(statement).all())

    def list_mobile(self) -> list[FAQEntry]:
        return self.list_admin(is_active=True, is_published=True)

    def get_by_id(self, faq_id: str) -> FAQEntry | None:
        statement = select(FAQEntry).where(FAQEntry.id == faq_id)
        return self.db.scalar(statement)

    def create(self, payload: dict[str, object]) -> FAQEntry:
        faq = FAQEntry(**payload)
        self.db.add(faq)
        self.db.commit()
        self.db.refresh(faq)
        return faq

    def save(self, faq: FAQEntry) -> FAQEntry:
        self.db.add(faq)
        self.db.commit()
        self.db.refresh(faq)
        return faq
