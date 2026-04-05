from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class Branch(Base):
    __tablename__ = 'branches'

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    city: Mapped[str] = mapped_column(String(120))
    address: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

