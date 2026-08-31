from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class TicketRedemption(Base):
    __tablename__ = 'ticket_redemptions'
    __table_args__ = (
        UniqueConstraint('issued_ticket_id', name='uq_ticket_redemptions_issued_ticket'),
        Index('ix_ticket_redemptions_branch_id', 'branch_id'),
        Index('ix_ticket_redemptions_admin_user_id', 'redeemed_by_admin_user_id'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    issued_ticket_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('issued_tickets.id', ondelete='CASCADE'),
        nullable=False,
    )
    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='RESTRICT'),
        nullable=False,
    )
    redeemed_by_admin_user_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('admin_users.id', ondelete='RESTRICT'),
        nullable=False,
    )
    redeemed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
