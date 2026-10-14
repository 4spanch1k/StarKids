from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class CustomerPass(Base):
    __tablename__ = 'customer_passes'
    __table_args__ = (
        UniqueConstraint('mobile_payment_id', name='uq_customer_passes_mobile_payment_id'),
        CheckConstraint('remaining_visits >= 0', name='ck_customer_passes_remaining_non_negative'),
        CheckConstraint(
            'remaining_visits <= visit_limit_snapshot',
            name='ck_customer_passes_remaining_within_limit',
        ),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('mobile_users.id', ondelete='RESTRICT'), nullable=False, index=True
    )
    child_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('mobile_children.id', ondelete='RESTRICT'), nullable=False, index=True
    )
    mobile_payment_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('mobile_payments.id', ondelete='RESTRICT'), nullable=False, index=True
    )
    pass_plan_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('pass_plans.id', ondelete='RESTRICT'), nullable=False, index=True
    )
    name_snapshot: Mapped[str] = mapped_column(String(120), nullable=False)
    price_tenge_snapshot: Mapped[int] = mapped_column(Integer, nullable=False)
    visit_limit_snapshot: Mapped[int] = mapped_column(Integer, nullable=False)
    validity_days_snapshot: Mapped[int] = mapped_column(Integer, nullable=False)
    daily_limit_snapshot: Mapped[int] = mapped_column(Integer, nullable=False)
    branch_id_snapshot: Mapped[str | None] = mapped_column(
        String(32), ForeignKey('branches.id', ondelete='RESTRICT'), nullable=True, index=True
    )
    activated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    remaining_visits: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default='active', index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
