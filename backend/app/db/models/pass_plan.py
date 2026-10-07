from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class PassPlan(Base):
    __tablename__ = 'pass_plans'
    __table_args__ = (
        CheckConstraint('price_tenge > 0', name='ck_pass_plans_price_positive'),
        CheckConstraint('visit_limit > 0', name='ck_pass_plans_visit_limit_positive'),
        CheckConstraint('validity_days > 0', name='ck_pass_plans_validity_positive'),
        CheckConstraint('daily_limit >= 1', name='ck_pass_plans_daily_limit_positive'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    price_tenge: Mapped[int] = mapped_column(Integer, nullable=False)
    visit_limit: Mapped[int] = mapped_column(Integer, nullable=False)
    validity_days: Mapped[int] = mapped_column(Integer, nullable=False)
    daily_limit: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    branch_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey('branches.id', ondelete='RESTRICT'), nullable=True, index=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
