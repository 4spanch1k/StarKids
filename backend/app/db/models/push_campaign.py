from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, JSON, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class PushCampaign(Base):
    __tablename__ = 'push_campaigns'
    __table_args__ = (
        CheckConstraint(
            "audience_type IN ('all_users', 'birthday_in_days', 'user')",
            name='ck_push_campaigns_audience_type',
        ),
        CheckConstraint(
            "origin IN ('manual', 'system_birthday')",
            name='ck_push_campaigns_origin',
        ),
        CheckConstraint(
            "destination IN ('home', 'tickets', 'birthdays', 'promotions', 'profile')",
            name='ck_push_campaigns_destination',
        ),
        CheckConstraint(
            "status IN ('draft', 'scheduled', 'processing', 'sent', 'failed', 'cancelled')",
            name='ck_push_campaigns_status',
        ),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    internal_name: Mapped[str] = mapped_column(String(150), nullable=False)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    audience_type: Mapped[str] = mapped_column(String(32), nullable=False)
    audience_config: Mapped[dict[str, object]] = mapped_column(JSON, nullable=False, default=dict)
    destination: Mapped[str] = mapped_column(String(32), nullable=False)
    destination_payload: Mapped[dict[str, object]] = mapped_column(JSON, nullable=False, default=dict)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default='draft', index=True)
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_by_admin_id: Mapped[str | None] = mapped_column(
        String(32),
        ForeignKey('admin_users.id', ondelete='RESTRICT'),
        nullable=True,
        index=True,
    )
    origin: Mapped[str] = mapped_column(String(32), nullable=False, default='manual', server_default='manual')
    targeted_users: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default='0')
    targeted_devices: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default='0')
    sent_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default='0')
    failed_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default='0')
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )
