from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.birthday_package import BirthdayPackage
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.branch_repository import BranchRepository
from .schemas import (
    AdminBirthdayPackageCreateRequest,
    AdminBirthdayPackageDetailResponse,
    AdminBirthdayPackageListQuery,
    AdminBirthdayPackageSummaryResponse,
    AdminBirthdayPackageUpdateRequest,
)

BIRTHDAY_PACKAGE_ADMIN_ALLOWED_ROLES = ('super_admin', 'content_manager')


class AdminBirthdayPackageService:
    def __init__(
        self,
        *,
        repository: BirthdayPackageRepository | None = None,
        branch_repository: BranchRepository | None = None,
    ) -> None:
        self.repository = repository or BirthdayPackageRepository()
        self.branch_repository = branch_repository or BranchRepository()

    def list_packages(
        self,
        query: AdminBirthdayPackageListQuery,
    ) -> list[AdminBirthdayPackageSummaryResponse]:
        if query.branch_id:
            self._ensure_branch_exists(query.branch_id)
        return [
            AdminBirthdayPackageSummaryResponse.model_validate(package)
            for package in self.repository.list_all(
                branch_id=query.branch_id,
                include_inactive=query.include_inactive,
            )
        ]

    def get_package(self, package_id: str) -> AdminBirthdayPackageDetailResponse:
        package = self._get_package_or_404(package_id)
        return AdminBirthdayPackageDetailResponse.model_validate(package)

    def create_package(
        self,
        payload: AdminBirthdayPackageCreateRequest,
    ) -> AdminBirthdayPackageDetailResponse:
        self._ensure_branch_exists(payload.branch_id)
        self._ensure_slug_available(payload.slug)
        package = self.repository.create(payload.model_dump())
        return AdminBirthdayPackageDetailResponse.model_validate(package)

    def update_package(
        self,
        package_id: str,
        payload: AdminBirthdayPackageUpdateRequest,
    ) -> AdminBirthdayPackageDetailResponse:
        package = self._get_package_or_404(package_id)
        changes = payload.model_dump(exclude_unset=True)
        if not changes:
            return AdminBirthdayPackageDetailResponse.model_validate(package)

        if 'branch_id' in changes:
            self._ensure_branch_exists(changes['branch_id'])
        if 'slug' in changes:
            self._ensure_slug_available(changes['slug'], exclude_id=package.id)

        for key, value in changes.items():
            setattr(package, key, value)

        saved = self.repository.save(package)
        return AdminBirthdayPackageDetailResponse.model_validate(saved)

    def _ensure_branch_exists(self, branch_id: str) -> None:
        if self.branch_repository.get_by_id(branch_id) is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Branch was not found.',
            )

    def _get_package_or_404(self, package_id: str) -> BirthdayPackage:
        package = self.repository.get_by_id(package_id)
        if package is None:
            raise NotFoundException(
                code='birthday_package_not_found',
                message='Birthday package was not found.',
            )
        return package

    def _ensure_slug_available(
        self,
        slug: str,
        *,
        exclude_id: str | None = None,
    ) -> None:
        if self.repository.slug_exists(slug, exclude_id=exclude_id):
            raise DomainHTTPException(
                code='birthday_package_slug_taken',
                message='Birthday package slug is already in use.',
                status_code=422,
                details=[
                    {
                        'field': 'slug',
                        'message': 'Birthday package slug is already in use.',
                    }
                ],
            )
