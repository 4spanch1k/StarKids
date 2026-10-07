from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, Integer, Index, String, func, text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class MobileOtpChallenge(Base):
    """A single-use, persisted phone verification challenge.

    The code is never stored in plaintext.  The challenge is deliberately
    independent from ``MobileUser`` because a phone may belong to a new
    account until the first successful verification.
    """

    __tablename__ = 'mobile_otp_challenges'
    __table_args__ = (
        CheckConstraint('attempt_count >= 0', name='ck_mobile_otp_attempt_count'),
        CheckConstraint('max_attempts > 0', name='ck_mobile_otp_max_attempts'),
        Index('ix_mobile_otp_challenges_phone_created', 'phone', 'created_at'),
        Index(
            'uq_mobile_otp_challenges_active_phone',
            'phone',
            unique=True,
            postgresql_where=text('consumed_at IS NULL'),
            sqlite_where=text('consumed_at IS NULL'),
        ),
    )

    id: Mapped[str] = mapped_column(
        String(64), primary_key=True, default=lambda: f'otp_{uuid4().hex}'
    )
    phone: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    max_attempts: Mapped[int] = mapped_column(Integer, nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
