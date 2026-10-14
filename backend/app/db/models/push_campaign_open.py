from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class PushCampaignOpen(Base):
    """The first authenticated open of a campaign by a mobile family."""

    __tablename__ = 'push_campaign_opens'
    __table_args__ = (
        UniqueConstraint(
            'campaign_id',
            'mobile_user_id',
            name='uq_push_campaign_opens_campaign_user',
        ),
    )

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    campaign_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('push_campaigns.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    mobile_user_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('mobile_users.id', ondelete='RESTRICT'),
        nullable=False,
        index=True,
    )
    opened_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
