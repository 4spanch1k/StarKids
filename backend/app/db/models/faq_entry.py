from uuid import uuid4

from sqlalchemy import Boolean, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class FAQEntry(Base):
    __tablename__ = 'faq_entries'

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    question: Mapped[str] = mapped_column(String(255))
    answer: Mapped[str] = mapped_column(Text)
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False)
