from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class BranchPricingProfile(Base):
    __tablename__ = 'branch_pricing_profiles'

    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='CASCADE'),
        primary_key=True,
    )
    intro_title: Mapped[str] = mapped_column(String(255))
    intro_description: Mapped[str] = mapped_column(Text)
    birthday_note: Mapped[str] = mapped_column(Text)
    disclaimer: Mapped[str | None] = mapped_column(Text, nullable=True)
