from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class BirthdayRevenueCycle(Base):
    """One family birthday occurrence used for CRM experiment measurement."""

    __tablename__ = 'birthday_revenue_cycles'
    __table_args__ = (
        UniqueConstraint(
            'mobile_user_id', 'birthday_year', 'target_date',
            name='uq_birthday_revenue_cycle_family_occurrence',
        ),
        CheckConstraint(
            "experiment_group IN ('control', 'treatment')",
            name='ck_birthday_revenue_cycle_experiment_group',
        ),
        Index('ix_birthday_revenue_cycles_user', 'mobile_user_id'),
        Index('ix_birthday_revenue_cycles_target', 'target_date'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('mobile_users.id', ondelete='RESTRICT'), nullable=False
    )
    birthday_year: Mapped[int] = mapped_column(Integer, nullable=False)
    target_date: Mapped[date] = mapped_column(Date, nullable=False)
    experiment_group: Mapped[str] = mapped_column(String(16), nullable=False)
    eligible_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )
