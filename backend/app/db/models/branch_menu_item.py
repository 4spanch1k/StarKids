from uuid import uuid4

from sqlalchemy import Boolean, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class BranchMenuItem(Base):
    __tablename__ = 'branch_menu_items'

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=lambda: uuid4().hex)
    branch_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branches.id', ondelete='CASCADE'),
        index=True,
    )
    category_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey('branch_menu_categories.id', ondelete='CASCADE'),
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255))
    price_tenge: Mapped[int] = mapped_column(Integer, default=0)
    image_url: Mapped[str] = mapped_column(String(1024))
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
