from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import Date, DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class PassRedemption(Base):
    __tablename__ = 'pass_redemptions'
    __table_args__ = (
        UniqueConstraint('customer_pass_id', 'business_date', name='uq_pass_redemptions_pass_business_date'),
        Index('ix_pass_redemptions_branch_id', 'branch_id'),
        Index('ix_pass_redemptions_visit_id', 'visit_id'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    customer_pass_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('customer_passes.id', ondelete='CASCADE'), nullable=False
    )
    visit_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('visits.id', ondelete='RESTRICT'), nullable=False
    )
    branch_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('branches.id', ondelete='RESTRICT'), nullable=False
    )
    redeemed_by_admin_user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('admin_users.id', ondelete='RESTRICT'), nullable=False
    )
    business_date: Mapped[date] = mapped_column(Date, nullable=False)
    redeemed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    source: Mapped[str] = mapped_column(String(16), nullable=False, default='scan')
    reason: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
