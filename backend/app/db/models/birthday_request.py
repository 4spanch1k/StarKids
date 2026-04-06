from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import Date, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class BirthdayRequest(Base):
    __tablename__ = 'birthday_requests'

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='RESTRICT'),
        index=True,
    )
    birthday_package_id: Mapped[str | None] = mapped_column(
        String(32),
        ForeignKey('birthday_packages.id', ondelete='SET NULL'),
        nullable=True,
        index=True,
    )
    customer_name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(32))
    child_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    child_age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    guest_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    requested_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    contact_method: Mapped[str] = mapped_column(String(32), default='phone')
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    source: Mapped[str] = mapped_column(String(64), default='mobile_app')
    status: Mapped[str] = mapped_column(String(32), default='new')
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
