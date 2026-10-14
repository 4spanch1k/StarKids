from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class MobilePaymentCallback(Base):
    __tablename__ = 'mobile_payment_callbacks'

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_payment_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('mobile_payments.id', ondelete='CASCADE'),
        index=True,
    )
    local_order_id: Mapped[str] = mapped_column(String(64), index=True)
    provider_event_id: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    payload_fingerprint: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    payload: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    result: Mapped[str] = mapped_column(String(32))
    status_before: Mapped[str] = mapped_column(String(32))
    status_after: Mapped[str] = mapped_column(String(32))
    failure_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    duplicate_count: Mapped[int] = mapped_column(Integer, default=0)
    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
