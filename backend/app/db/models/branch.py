from uuid import uuid4

from sqlalchemy import Boolean, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class Branch(Base):
    __tablename__ = 'branches'

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    slug: Mapped[str] = mapped_column(String(120), unique=True)
    name: Mapped[str] = mapped_column(String(255))
    city: Mapped[str] = mapped_column(String(120))
    address: Mapped[str] = mapped_column(String(255))
    short_label: Mapped[str] = mapped_column(String(120))
    working_hours: Mapped[str] = mapped_column(String(255))
    description: Mapped[str] = mapped_column(Text)
    phone: Mapped[str] = mapped_column(String(32))
    whatsapp_phone: Mapped[str] = mapped_column(String(32))
    hero_image_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    gallery_image_urls: Mapped[list[str]] = mapped_column(JSON, default=list)
    facilities: Mapped[list[str]] = mapped_column(JSON, default=list)
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
