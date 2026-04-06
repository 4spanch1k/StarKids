from sqlalchemy import select

from ..models.birthday_package import BirthdayPackage
from .base import Repository


class BirthdayPackageRepository(Repository):
    def list_active(self, branch_id: str | None = None) -> list[BirthdayPackage]:
        statement = select(BirthdayPackage).where(BirthdayPackage.is_active.is_(True))
        if branch_id:
            statement = statement.where(BirthdayPackage.branch_id == branch_id)
        statement = statement.order_by(
            BirthdayPackage.display_order.asc(),
            BirthdayPackage.price_from.asc(),
        )
        return list(self.db.scalars(statement).all())

    def get_active_by_id(self, package_id: str) -> BirthdayPackage | None:
        statement = select(BirthdayPackage).where(
            BirthdayPackage.id == package_id,
            BirthdayPackage.is_active.is_(True),
        )
        return self.db.scalar(statement)
