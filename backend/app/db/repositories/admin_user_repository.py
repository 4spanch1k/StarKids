from datetime import UTC, datetime

from sqlalchemy import func, select

from ..models.admin_user import AdminUser
from .base import Repository


class AdminUserRepository(Repository):
    def exists_any(self) -> bool:
        total = self.db.scalar(select(func.count()).select_from(AdminUser))
        return bool(total)

    def find_by_email(self, email: str) -> AdminUser | None:
        return self.db.scalar(
            select(AdminUser).where(AdminUser.email == email.lower().strip())
        )

    def get_by_id(self, user_id: str) -> AdminUser | None:
        return self.db.scalar(select(AdminUser).where(AdminUser.id == user_id))

    def create(
        self,
        *,
        email: str,
        full_name: str,
        password_hash: str,
        role: str,
        is_active: bool = True,
    ) -> AdminUser:
        user = AdminUser(
            email=email.lower().strip(),
            full_name=full_name.strip(),
            password_hash=password_hash,
            role=role,
            is_active=is_active,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def update_password_hash(
        self,
        user: AdminUser,
        *,
        password_hash: str,
    ) -> AdminUser:
        user.password_hash = password_hash
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def record_successful_login(self, user: AdminUser) -> AdminUser:
        user.last_login_at = datetime.now(UTC)
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user
