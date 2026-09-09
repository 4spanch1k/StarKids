from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class BirthdayRequest(Base):
    __tablename__ = 'birthday_requests'
    __table_args__ = (
        UniqueConstraint('mobile_user_id', 'idempotency_key', name='uq_birthday_requests_user_idempotency'),
        CheckConstraint(
            'agreed_amount_tenge IS NULL OR agreed_amount_tenge >= 0',
            name='ck_birthday_requests_agreed_amount_non_negative',
        ),
        CheckConstraint(
            'expected_amount_tenge IS NULL OR expected_amount_tenge >= 0',
            name='ck_birthday_requests_expected_amount_non_negative',
        ),
        CheckConstraint(
            'deposit_amount_tenge IS NULL OR deposit_amount_tenge >= 0',
            name='ck_birthday_requests_deposit_amount_non_negative',
        ),
        CheckConstraint(
            'paid_amount_tenge IS NULL OR paid_amount_tenge >= 0',
            name='ck_birthday_requests_paid_amount_non_negative',
        ),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_user_id: Mapped[str | None] = mapped_column(
        String(32),
        ForeignKey('mobile_users.id', ondelete='SET NULL'),
        nullable=True,
        index=True,
    )
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
    child_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey('mobile_children.id', ondelete='SET NULL'), nullable=True, index=True
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
    idempotency_key: Mapped[str | None] = mapped_column(String(128), nullable=True)
    child_name_snapshot: Mapped[str | None] = mapped_column(String(120), nullable=True)
    child_birth_date_snapshot: Mapped[date | None] = mapped_column(Date, nullable=True)
    package_name_snapshot: Mapped[str | None] = mapped_column(String(255), nullable=True)
    package_price_snapshot: Mapped[int | None] = mapped_column(Integer, nullable=True)
    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    # agreed_amount_tenge is retained for API/database compatibility with the
    # previous funnel version. New sales code treats expected_amount_tenge as
    # the canonical expected booking value and keeps the legacy field in sync.
    agreed_amount_tenge: Mapped[int | None] = mapped_column(Integer, nullable=True)
    expected_amount_tenge: Mapped[int | None] = mapped_column(Integer, nullable=True)
    deposit_amount_tenge: Mapped[int | None] = mapped_column(Integer, nullable=True)
    paid_amount_tenge: Mapped[int | None] = mapped_column(Integer, nullable=True)
    lost_reason: Mapped[str | None] = mapped_column(String(32), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    contacted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    qualified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    booked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    lost_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
