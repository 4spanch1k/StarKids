from datetime import datetime
from uuid import uuid4

from sqlalchemy import BigInteger, CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class LoyaltyAccount(Base):
    __tablename__ = 'loyalty_accounts'
    __table_args__ = (
        UniqueConstraint('mobile_user_id', name='uq_loyalty_accounts_mobile_user_id'),
        CheckConstraint('balance >= 0', name='ck_loyalty_accounts_balance_nonnegative'),
        CheckConstraint('reserved_balance >= 0', name='ck_loyalty_accounts_reserved_nonnegative'),
        CheckConstraint('reserved_balance <= balance', name='ck_loyalty_accounts_reserved_le_balance'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_user_id: Mapped[str] = mapped_column(String(32), ForeignKey('mobile_users.id', ondelete='RESTRICT'), nullable=False, index=True)
    balance: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    reserved_balance: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    lifetime_earned: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    lifetime_spent: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
