from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class LifecycleJourneyExecution(Base):
    """Durable assignment and outcome for lifecycle experiments."""

    __tablename__ = 'lifecycle_journey_executions'
    __table_args__ = (
        UniqueConstraint('journey_key', 'mobile_user_id', name='uq_lifecycle_journey_user'),
        UniqueConstraint('push_campaign_id', name='uq_lifecycle_journey_campaign'),
        CheckConstraint("experiment_group IN ('control', 'treatment')", name='ck_lifecycle_experiment_group'),
        Index('ix_lifecycle_journey_eligible_at', 'journey_key', 'eligible_at'),
        Index('ix_lifecycle_journey_campaign', 'push_campaign_id'),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    journey_key: Mapped[str] = mapped_column(String(64), nullable=False)
    mobile_user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('mobile_users.id', ondelete='RESTRICT'), nullable=False, index=True
    )
    experiment_group: Mapped[str] = mapped_column(String(16), nullable=False)
    eligible_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    anchor_visit_id: Mapped[str] = mapped_column(
        String(32), ForeignKey('visits.id', ondelete='RESTRICT'), nullable=False
    )
    anchor_visit_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    push_campaign_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey('push_campaigns.id', ondelete='SET NULL'), nullable=True
    )
    push_sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    converted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    conversion_visit_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey('visits.id', ondelete='SET NULL'), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )
