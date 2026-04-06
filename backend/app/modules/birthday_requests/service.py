from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.birthday_request_repository import BirthdayRequestRepository
from ...db.repositories.branch_repository import BranchRepository
from .schemas import BirthdayRequestCreate, BirthdayRequestCreatedResponse


class BirthdayRequestService:
    def __init__(
        self,
        *,
        request_repository: BirthdayRequestRepository | None = None,
        branch_repository: BranchRepository | None = None,
        package_repository: BirthdayPackageRepository | None = None,
    ) -> None:
        self.request_repository = request_repository or BirthdayRequestRepository()
        self.branch_repository = branch_repository or BranchRepository()
        self.package_repository = package_repository or BirthdayPackageRepository()

    def create_request(
        self,
        payload: BirthdayRequestCreate,
    ) -> BirthdayRequestCreatedResponse:
        branch = self.branch_repository.get_active_by_id(payload.branch_id)
        if branch is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Branch was not found.',
            )

        if payload.birthday_package_id:
            package = self.package_repository.get_active_by_id(payload.birthday_package_id)
            if package is None:
                raise NotFoundException(
                    code='birthday_package_not_found',
                    message='Birthday package was not found.',
                )
            if package.branch_id != payload.branch_id:
                raise DomainHTTPException(
                    code='birthday_package_branch_mismatch',
                    message='Birthday package does not belong to the selected branch.',
                    status_code=422,
                    details=[
                        {
                            'field': 'birthday_package_id',
                            'message': 'Package must belong to the selected branch.',
                        }
                    ],
                )

        created_request = self.request_repository.create(payload.model_dump())
        return BirthdayRequestCreatedResponse.model_validate(created_request)
