from sqlalchemy import select

from ..models.mobile_user import MobileUser
from .base import Repository


class MobileUserRepository(Repository):
    def find_by_phone(self, phone: str) -> MobileUser | None:
        return self.db.scalar(select(MobileUser).where(MobileUser.phone == phone.strip()))

    def get_by_id(self, user_id: str) -> MobileUser | None:
        return self.db.scalar(select(MobileUser).where(MobileUser.id == user_id))

    def create(
        self,
        *,
        phone: str,
        is_active: bool = True,
    ) -> MobileUser:
        user = MobileUser(
            phone=phone.strip(),
            is_active=is_active,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user
