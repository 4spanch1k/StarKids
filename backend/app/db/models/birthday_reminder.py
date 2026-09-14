from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class BirthdayReminder(Base):
    __tablename__ = 'birthday_reminders'
    __table_args__ = (
        UniqueConstraint(
            'child_id', 'birthday_year', 'days_before',
            name='uq_birthday_reminders_child_year_window',
        ),
        CheckConstraint(
            "status IN ('pending', 'sent', 'skipped', 'failed')",
            name='ck_birthday_reminders_status',
        ),
        CheckConstraint('days_before IN (14, 7, 1)', name='ck_birthday_reminders_days_before'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    # SET NULL preserves reminder history if a parent deletes a child.
    child_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey('mobile_children.id', ondelete='SET NULL'), nullable=True, index=True
    )
    mobile_user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('mobile_users.id', ondelete='RESTRICT'), nullable=False, index=True
    )
    birthday_year: Mapped[int] = mapped_column(Integer, nullable=False)
    days_before: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default='pending', server_default='pending', index=True)
    push_campaign_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey('push_campaigns.id', ondelete='SET NULL'), nullable=True, index=True
    )
    skip_reason: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    skipped_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
