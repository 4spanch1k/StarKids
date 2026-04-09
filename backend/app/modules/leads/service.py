from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.lead_repository import LeadRepository
from .constants import LEAD_TYPE_CONTACT
from .schemas import (
    BirthdayLeadCreate,
    BirthdayLeadSubmittedResponse,
    ContactLeadCreate,
    LeadCreatedResponse,
)


class LeadService:
    def __init__(
        self,
        repository: LeadRepository | None = None,
        branch_repository: BranchRepository | None = None,
        package_repository: BirthdayPackageRepository | None = None,
    ) -> None:
        self.repository = repository or LeadRepository()
        self.branch_repository = branch_repository or BranchRepository()
        self.package_repository = package_repository or BirthdayPackageRepository()

    def create_contact_lead(
        self,
        payload: ContactLeadCreate,
        *,
        mobile_user_id: str | None = None,
    ) -> LeadCreatedResponse:
        lead = self.repository.create_contact_lead(
            {
                'mobile_user_id': mobile_user_id,
                'customer_name': payload.name,
                'phone': payload.phone,
                'email': payload.email,
                'message': payload.message,
            }
        )
        return LeadCreatedResponse(
            id=lead.id,
            type=LEAD_TYPE_CONTACT,
            status=lead.status,
        )

    def create_birthday_lead(
        self,
        payload: BirthdayLeadCreate,
        *,
        mobile_user_id: str | None = None,
    ) -> BirthdayLeadSubmittedResponse:
        branch = self.branch_repository.get_active_by_id(payload.branchId)
        if branch is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Selected branch was not found.',
                details=[{'field': 'branchId', 'message': 'Selected branch was not found.'}],
            )

        if payload.packageId:
            package = self.package_repository.get_active_by_id(payload.packageId)
            if package is None:
                raise NotFoundException(
                    code='package_not_found',
                    message='Selected package was not found.',
                    details=[{'field': 'packageId', 'message': 'Selected package was not found.'}],
                )
            if package.branch_id != payload.branchId:
                raise DomainHTTPException(
                    code='package_branch_mismatch',
                    message='Selected package does not belong to the selected branch.',
                    status_code=422,
                    details=[
                        {
                            'field': 'packageId',
                            'message': 'Selected package must belong to the selected branch.',
                        }
                    ],
                )

        request = self.repository.create_birthday_lead(
            {
                'mobile_user_id': mobile_user_id,
                'branch_id': payload.branchId,
                'birthday_package_id': payload.packageId,
                'customer_name': payload.name,
                'phone': payload.phone,
                'requested_date': payload.preferredDate,
                'guest_count': payload.guestCount,
                'notes': payload.comment,
            }
        )
        return BirthdayLeadSubmittedResponse(
            requestId=request.id,
            submittedAt=request.created_at,
            nextStep='Менеджер свяжется с вами для подтверждения деталей',
        )
