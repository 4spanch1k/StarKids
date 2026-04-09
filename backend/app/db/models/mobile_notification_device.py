from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from .base import Base


class MobileNotificationDevice(Base):
    __tablename__ = 'mobile_notification_devices'
    __table_args__ = (
        UniqueConstraint(
            'mobile_session_id',
            name='uq_mobile_notification_devices_mobile_session_id',
        ),
        UniqueConstraint(
            'push_token',
            name='uq_mobile_notification_devices_push_token',
        ),
    )

    id: Mapped[str] = mapped_column(
        String(32),
        primary_key=True,
        default=lambda: uuid4().hex,
    )
    mobile_user_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('mobile_users.id', ondelete='CASCADE'),
        index=True,
    )
    mobile_session_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('mobile_sessions.id', ondelete='CASCADE'),
    )
    platform: Mapped[str] = mapped_column(String(16))
    push_token: Mapped[str] = mapped_column(String(512))
    permission_status: Mapped[str] = mapped_column(String(32), default='unknown')
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
