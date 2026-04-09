from sqlalchemy import select

from ..models.birthday_package import BirthdayPackage
from .base import Repository


class BirthdayPackageRepository(Repository):
    def list_all(
        self,
        branch_id: str | None = None,
        include_inactive: bool = True,
    ) -> list[BirthdayPackage]:
        statement = select(BirthdayPackage)
        if not include_inactive:
            statement = statement.where(BirthdayPackage.is_active.is_(True))
        if branch_id:
            statement = statement.where(BirthdayPackage.branch_id == branch_id)
        statement = statement.order_by(
            BirthdayPackage.display_order.asc(),
            BirthdayPackage.price_from.asc(),
        )
        return list(self.db.scalars(statement).all())

    def list_active(self, branch_id: str | None = None) -> list[BirthdayPackage]:
        return self.list_all(branch_id=branch_id, include_inactive=False)

    def get_by_id(self, package_id: str) -> BirthdayPackage | None:
        statement = select(BirthdayPackage).where(BirthdayPackage.id == package_id)
        return self.db.scalar(statement)

    def get_active_by_id(self, package_id: str) -> BirthdayPackage | None:
        package = self.get_by_id(package_id)
        if package is None or not package.is_active:
            return None
        return package

    def slug_exists(self, slug: str, exclude_id: str | None = None) -> bool:
        statement = select(BirthdayPackage.id).where(BirthdayPackage.slug == slug)
        if exclude_id:
            statement = statement.where(BirthdayPackage.id != exclude_id)
        return self.db.scalar(statement) is not None

    def create(self, payload: dict[str, object]) -> BirthdayPackage:
        package = BirthdayPackage(**payload)
        self.db.add(package)
        self.db.commit()
        self.db.refresh(package)
        return package

    def save(self, package: BirthdayPackage) -> BirthdayPackage:
        self.db.add(package)
        self.db.commit()
        self.db.refresh(package)
        return package
