from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from .base import Base


class AuthThrottleState(Base):
    __tablename__ = 'auth_throttle_states'
    __table_args__ = (
        UniqueConstraint(
            'auth_scope',
            'bucket_type',
            'bucket_key',
            name='uq_auth_throttle_states_scope_bucket',
        ),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    auth_scope: Mapped[str] = mapped_column(String(64), index=True)
    bucket_type: Mapped[str] = mapped_column(String(32), index=True)
    bucket_key: Mapped[str] = mapped_column(String(255))
    ip_address: Mapped[str] = mapped_column(String(64), index=True)
    identifier: Mapped[str | None] = mapped_column(String(255), nullable=True)
    failed_attempts: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default=text('0'),
    )
    total_lockouts: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default=text('0'),
    )
    post_lock_failures: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default=text('0'),
    )
    lockout_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    captcha_required: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text('0'),
    )
    captcha_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    captcha_prompt: Mapped[str | None] = mapped_column(String(255), nullable=True)
    captcha_answer_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    captcha_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_failed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_success_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
