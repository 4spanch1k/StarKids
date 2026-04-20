from __future__ import annotations

from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy import select

from ..models.mobile_user import MobileUser
from .base import Repository

_SENTINEL = object()


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

    def update(
        self,
        user: MobileUser,
        *,
        first_name: Any = _SENTINEL,
        last_name: Any = _SENTINEL,
        email: Any = _SENTINEL,
        avatar_url: Any = _SENTINEL,
        child_birth_date: Any = _SENTINEL,
    ) -> MobileUser:
        if first_name is not _SENTINEL:
            user.first_name = first_name
        if last_name is not _SENTINEL:
            user.last_name = last_name
        if email is not _SENTINEL:
            user.email = email.lower().strip() if email is not None else None
        if avatar_url is not _SENTINEL:
            user.avatar_url = avatar_url
        if child_birth_date is not _SENTINEL:
            user.child_birth_date = child_birth_date
        self.db.commit()
        self.db.refresh(user)
        return user

    def update_password_hash(
        self,
        user: MobileUser,
        *,
        password_hash: str,
    ) -> MobileUser:
        user.password_hash = password_hash
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def record_successful_login(self, user: MobileUser) -> MobileUser:
        user.last_login_at = datetime.now(UTC)
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user
