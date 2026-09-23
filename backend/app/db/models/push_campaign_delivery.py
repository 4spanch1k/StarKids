from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class PushCampaignDelivery(Base):
    __tablename__ = 'push_campaign_deliveries'
    __table_args__ = (
        UniqueConstraint(
            'campaign_id', 'device_id',
            name='uq_push_campaign_deliveries_campaign_device',
        ),
        CheckConstraint(
            "status IN ('pending', 'sending', 'sent', 'failed')",
            name='ck_push_campaign_deliveries_status',
        ),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    campaign_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('push_campaigns.id', ondelete='CASCADE'), nullable=False, index=True
    )
    mobile_user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('mobile_users.id', ondelete='RESTRICT'), nullable=False, index=True
    )
    device_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey('mobile_notification_devices.id', ondelete='SET NULL'), nullable=True, index=True
    )
    token_snapshot: Mapped[str] = mapped_column(String(512), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default='pending', index=True)
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default='0')
    provider_message_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    last_error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    last_error_message: Mapped[str | None] = mapped_column(String(255), nullable=True)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )
