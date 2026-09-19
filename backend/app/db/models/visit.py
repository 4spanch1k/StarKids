from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class Visit(Base):
    """Physical admission created by the first successful ticket redemption."""

    __tablename__ = 'visits'
    __table_args__ = (
        UniqueConstraint('mobile_payment_id', name='uq_visits_mobile_payment_id'),
        Index('ix_visits_mobile_user_status', 'mobile_user_id', 'status'),
        Index('ix_visits_branch_started_at', 'branch_id', 'started_at'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    mobile_payment_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('mobile_payments.id', ondelete='RESTRICT'),
        nullable=False,
    )
    mobile_user_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('mobile_users.id', ondelete='RESTRICT'),
        nullable=False,
    )
    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='RESTRICT'),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(String(32), nullable=False, default='active')
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # When no operational checkout exists, this is the server-side validity
    # cutoff rather than a claim about the customer's physical exit time.
    completion_reason: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
