from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import (
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class IssuedTicket(Base):
    __tablename__ = 'issued_tickets'
    __table_args__ = (
        UniqueConstraint(
            'mobile_payment_id',
            'line_index',
            name='uq_issued_tickets_payment_line_index',
        ),
        UniqueConstraint('ticket_number', name='uq_issued_tickets_ticket_number'),
        Index('ix_issued_tickets_payment_id', 'mobile_payment_id'),
        Index('ix_issued_tickets_status', 'status'),
        Index('ix_issued_tickets_visit_date', 'visit_date'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_payment_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('mobile_payments.id', ondelete='CASCADE'),
        nullable=False,
    )
    ticket_number: Mapped[str] = mapped_column(String(32), nullable=False)
    ticket_item_id: Mapped[str] = mapped_column(String(32), nullable=False)
    title_snapshot: Mapped[str] = mapped_column(String(255), nullable=False)
    price_tenge: Mapped[int] = mapped_column(Integer, nullable=False)
    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='RESTRICT'),
        nullable=False,
        index=True,
    )
    visit_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    line_index: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default='issued')
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
