from ...core.exceptions.http import NotFoundException
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.branch_repository import BranchRepository
from .schemas import BirthdayPackageDetail, BirthdayPackageSummary


class BirthdayService:
    def __init__(
        self,
        repository: BirthdayPackageRepository | None = None,
        branch_repository: BranchRepository | None = None,
    ) -> None:
        self.repository = repository or BirthdayPackageRepository()
        self.branch_repository = branch_repository or BranchRepository()

    def list_packages(self, branch_id: str | None = None) -> list[BirthdayPackageSummary]:
        resolved_branch_id: str | None = None
        if branch_id:
            branch = self.branch_repository.get_active_by_id_or_slug(branch_id)
            if branch is None:
                raise NotFoundException(
                    code='branch_not_found',
                    message='Branch was not found.',
                )
            resolved_branch_id = branch.id

        packages = self.repository.list_active(branch_id=resolved_branch_id)
        return [
            BirthdayPackageSummary.model_validate(package)
            for package in packages
            if self.branch_repository.get_active_by_id(package.branch_id) is not None
        ]

    def get_package(self, package_id: str) -> BirthdayPackageDetail:
        package = self.repository.get_active_by_id(package_id)
        if (
            package is None
            or self.branch_repository.get_active_by_id(package.branch_id) is None
        ):
            raise NotFoundException(
                code='birthday_package_not_found',
                message='Birthday package was not found.',
            )
        return BirthdayPackageDetail.model_validate(package)
