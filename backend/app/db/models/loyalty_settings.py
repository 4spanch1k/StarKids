from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, Numeric, SmallInteger, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class LoyaltySettings(Base):
    """Singleton configuration for redemption economics."""

    __tablename__ = 'loyalty_settings'
    __table_args__ = (
        CheckConstraint('id = 1', name='ck_loyalty_settings_singleton'),
        CheckConstraint('max_redemption_percent >= 0 AND max_redemption_percent <= 100', name='ck_loyalty_settings_max_redemption_percent'),
        CheckConstraint('bonus_value_kzt > 0', name='ck_loyalty_settings_bonus_value_positive'),
    )

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True, default=1)
    max_redemption_percent: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False, default=Decimal('0'))
    bonus_value_kzt: Mapped[Decimal] = mapped_column(Numeric(12, 4), nullable=False, default=Decimal('1'))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
