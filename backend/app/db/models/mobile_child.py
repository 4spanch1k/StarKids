from __future__ import annotations

from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import Date, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from .base import Base


class MobileChild(Base):
    __tablename__ = 'mobile_children'

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('mobile_users.id', ondelete='CASCADE'), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    birth_date: Mapped[date] = mapped_column(Date, nullable=False)
    # ``unspecified`` is a valid optional value (11 characters).
    gender: Mapped[str] = mapped_column(String(16), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
