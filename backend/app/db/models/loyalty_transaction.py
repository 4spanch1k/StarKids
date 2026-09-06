from datetime import datetime
from uuid import uuid4

from sqlalchemy import BigInteger, DateTime, ForeignKey, Index, JSON, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class LoyaltyTransaction(Base):
    __tablename__ = 'loyalty_transactions'
    __table_args__ = (
        UniqueConstraint('idempotency_key', name='uq_loyalty_transactions_idempotency_key'),
        UniqueConstraint('type', 'source_type', 'source_id', name='uq_loyalty_transactions_event_source'),
        Index('ix_loyalty_transactions_user_created', 'mobile_user_id', 'created_at'),
        Index('ix_loyalty_transactions_source', 'source_type', 'source_id'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_user_id: Mapped[str] = mapped_column(String(32), ForeignKey('mobile_users.id', ondelete='RESTRICT'), nullable=False, index=True)
    account_id: Mapped[str] = mapped_column(String(32), ForeignKey('loyalty_accounts.id', ondelete='RESTRICT'), nullable=False, index=True)
    type: Mapped[str] = mapped_column(String(16), nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    balance_delta: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    reserved_delta: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    source_type: Mapped[str] = mapped_column(String(32), nullable=False)
    source_id: Mapped[str] = mapped_column(String(128), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(191), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default='posted')
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[dict[str, object]] = mapped_column(JSON, nullable=False, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
