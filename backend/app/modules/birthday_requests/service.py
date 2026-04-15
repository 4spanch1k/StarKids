import logging

from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.birthday_request_repository import BirthdayRequestRepository
from ...db.repositories.branch_repository import BranchRepository
from ...services.push.push_service import PushService
from .schemas import BirthdayRequestCreate, BirthdayRequestCreatedResponse

logger = logging.getLogger(__name__)


class BirthdayRequestService:
    def __init__(
        self,
        *,
        request_repository: BirthdayRequestRepository | None = None,
        branch_repository: BranchRepository | None = None,
        package_repository: BirthdayPackageRepository | None = None,
        push_service: PushService | None = None,
    ) -> None:
        self.request_repository = request_repository or BirthdayRequestRepository()
        self.branch_repository = branch_repository or BranchRepository()
        self.package_repository = package_repository or BirthdayPackageRepository()
        self.push_service = push_service

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

        # Event trigger: notify staff when a new birthday request arrives.
        # Currently targets no users (admin push registration not yet implemented).
        # When admin/staff mobile users are registered, pass their user IDs here:
        #   self.push_service.notify_birthday_request_received(
        #       admin_user_ids=[...],
        #       branch_name=branch.name,
        #       parent_name=payload.parent_name,
        #   )
        # See PushService.notify_birthday_request_received for the full interface.
        if self.push_service is not None:
            logger.debug(
                'Push trigger point: birthday_request_received (branch_id=%s, parent=%s). '
                'No admin user IDs available yet — delivery skipped.',
                payload.branch_id,
                getattr(payload, 'parent_name', '?'),
            )

        return BirthdayRequestCreatedResponse.model_validate(created_request)
