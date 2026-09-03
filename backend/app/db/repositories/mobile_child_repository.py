from __future__ import annotations

from datetime import date

from sqlalchemy import select

from ..models.mobile_child import MobileChild
from .base import Repository


class MobileChildRepository(Repository):
    def list_for_user(self, user_id: str) -> list[MobileChild]:
        return list(
            self.db.scalars(
                select(MobileChild)
                .where(MobileChild.user_id == user_id)
                .order_by(MobileChild.created_at)
            )
        )

    def get_by_id_and_user(self, child_id: str, user_id: str) -> MobileChild | None:
        return self.db.scalar(
            select(MobileChild).where(
                MobileChild.id == child_id,
                MobileChild.user_id == user_id,
            )
        )

    def create(
        self,
        *,
        user_id: str,
        name: str,
        birth_date: date,
        gender: str,
    ) -> MobileChild:
        child = MobileChild(
            user_id=user_id,
            name=name.strip(),
            birth_date=birth_date,
            gender=gender,
        )
        self.db.add(child)
        self.db.commit()
        self.db.refresh(child)
        return child

    def update(
        self,
        child: MobileChild,
        *,
        name: str | None = None,
        birth_date: date | None = None,
        gender: str | None = None,
    ) -> MobileChild:
        if name is not None:
            child.name = name.strip()
        if birth_date is not None:
            child.birth_date = birth_date
        if gender is not None:
            child.gender = gender
        self.db.commit()
        self.db.refresh(child)
        return child

    def delete(self, child: MobileChild) -> None:
        self.db.delete(child)
        self.db.commit()
