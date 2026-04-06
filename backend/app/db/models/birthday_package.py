from uuid import uuid4

from sqlalchemy import Boolean, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class BirthdayPackage(Base):
    __tablename__ = 'birthday_packages'

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='CASCADE'),
        index=True,
    )
    slug: Mapped[str] = mapped_column(String(120), unique=True)
    name: Mapped[str] = mapped_column(String(255))
    price_from: Mapped[int] = mapped_column(Integer)
    price_label: Mapped[str] = mapped_column(String(64))
    guest_capacity_label: Mapped[str] = mapped_column(String(64))
    description: Mapped[str] = mapped_column(Text)
    highlights: Mapped[list[str]] = mapped_column(JSON, default=list)
    image_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    display_order: Mapped[int] = mapped_column(Integer, default=0)
