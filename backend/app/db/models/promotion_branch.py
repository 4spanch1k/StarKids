from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class PromotionBranch(Base):
    __tablename__ = 'promotion_branches'

    promotion_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('promotions.id', ondelete='CASCADE'),
        primary_key=True,
    )
    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='CASCADE'),
        primary_key=True,
    )
