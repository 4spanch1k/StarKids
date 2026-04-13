from sqlalchemy import select

from ..models.mobile_user import MobileUser
from .base import Repository


class MobileUserRepository(Repository):
    def find_by_phone(self, phone: str) -> MobileUser | None:
        return self.db.scalar(select(MobileUser).where(MobileUser.phone == phone.strip()))

    def find_by_email(self, email: str) -> MobileUser | None:
        return self.db.scalar(
            select(MobileUser).where(MobileUser.email == email.lower().strip())
        )

    def get_by_id(self, user_id: str) -> MobileUser | None:
        return self.db.scalar(select(MobileUser).where(MobileUser.id == user_id))

    def create(
        self,
        *,
        phone: str | None = None,
        email: str | None = None,
        password_hash: str | None = None,
        is_active: bool = True,
    ) -> MobileUser:
        normalized_phone = phone.strip() if phone is not None else None
        normalized_email = email.lower().strip() if email is not None else None
        if not normalized_phone and not normalized_email:
            raise ValueError('Mobile user requires phone or email.')

        user = MobileUser(
            phone=normalized_phone,
            email=normalized_email,
            password_hash=password_hash,
            is_active=is_active,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user
