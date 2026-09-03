from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import (
    Date,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class MobilePayment(Base):
    __tablename__ = 'mobile_payments'
    __table_args__ = (
        UniqueConstraint(
            'mobile_user_id',
            'idempotency_key',
            name='uq_mobile_payments_user_idempotency',
        ),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_user_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('mobile_users.id', ondelete='RESTRICT'),
        index=True,
    )
    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='RESTRICT'),
        index=True,
    )
    payable_entity_type: Mapped[str] = mapped_column(String(64))
    payable_entity_id: Mapped[str] = mapped_column(String(32), index=True)
    local_order_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    payment_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    external_payment_id: Mapped[str | None] = mapped_column(
        String(128),
        nullable=True,
        unique=True,
        index=True,
    )
    gateway: Mapped[str] = mapped_column(String(32), default='freedompay')
    amount_tenge: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3), default='KZT')
    quantity: Mapped[int] = mapped_column(Integer)
    visit_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    ticket_items: Mapped[list[dict[str, object]]] = mapped_column(JSON, default=list)
    status: Mapped[str] = mapped_column(String(32), default='created', index=True)
    init_payload: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    callback_payload: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    issued_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
