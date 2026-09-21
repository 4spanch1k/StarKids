from sqlalchemy.exc import IntegrityError
from sqlalchemy import select

from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.lead_repository import LeadRepository
from ...db.repositories.mobile_child_repository import MobileChildRepository
from ...db.models.birthday_revenue_cycle import BirthdayRevenueCycle
from ...db.models.birthday_reminder import BirthdayReminder
from ...db.models.push_campaign import PushCampaign
from ..admin_push_campaigns.service import birthday_occurrence_for_year
from .constants import LEAD_TYPE_CONTACT
from .schemas import (
    BirthdayLeadCreate,
    BirthdayLeadListResponse,
    BirthdayLeadResponse,
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
        child_repository: MobileChildRepository | None = None,
    ) -> None:
        self.repository = repository or LeadRepository()
        self.branch_repository = branch_repository or BranchRepository()
        self.package_repository = package_repository or BirthdayPackageRepository()
        self.child_repository = child_repository or MobileChildRepository()

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
        if payload.idempotencyKey:
            existing = self.repository.get_birthday_lead_by_idempotency_key(
                mobile_user_id=mobile_user_id,
                idempotency_key=payload.idempotencyKey,
            )
            if existing is not None:
                return self._response(existing)

        campaign = None
        cycle = None
        if payload.sourceCampaignId or payload.birthdayCycleId:
            if mobile_user_id is None:
                raise DomainHTTPException(code='birthday_context_requires_auth', message='Birthday campaign context requires authentication.', status_code=403)
            campaign = self.repository.db.get(PushCampaign, payload.sourceCampaignId) if payload.sourceCampaignId else None
            campaign_cycle_id = (campaign.destination_payload or {}).get('birthdayCycleId') if campaign else None
            cycle = self.repository.db.get(BirthdayRevenueCycle, payload.birthdayCycleId or campaign_cycle_id) if (payload.birthdayCycleId or campaign_cycle_id) else None
            if campaign is None or campaign.origin != 'system_birthday':
                raise DomainHTTPException(code='invalid_birthday_campaign', message='Birthday campaign context is invalid.', status_code=422)
            campaign_user = (campaign.audience_config or {}).get('user_id')
            payload_cycle_id = (campaign.destination_payload or {}).get('birthdayCycleId')
            if campaign_user != mobile_user_id or cycle is None or cycle.mobile_user_id != mobile_user_id or (payload_cycle_id and payload_cycle_id != cycle.id):
                raise DomainHTTPException(code='invalid_birthday_campaign', message='Birthday campaign context is invalid.', status_code=422)
            reminder_exists = self.repository.db.scalar(select(BirthdayReminder.id).where(BirthdayReminder.push_campaign_id == campaign.id, BirthdayReminder.birthday_cycle_id == cycle.id))
            if reminder_exists is None:
                raise DomainHTTPException(code='invalid_birthday_campaign', message='Birthday campaign context is invalid.', status_code=422)
        if cycle is not None and cycle.mobile_user_id != mobile_user_id:
            raise DomainHTTPException(code='invalid_birthday_cycle', message='Birthday cycle context is invalid.', status_code=422)

        child = None
        if mobile_user_id:
            if payload.childId is not None:
                child = self.child_repository.get_by_id_and_user(payload.childId, mobile_user_id)
            if payload.childId is not None and child is None:
                raise NotFoundException(
                    code='child_not_found',
                    message='Selected child was not found.',
                    details=[{'field': 'childId', 'message': 'Selected child was not found.'}],
                )

        # A validated campaign is still useful direct attribution even when
        # the parent changes the selected child. Only attach the cycle when
        # that child represents the campaign's birthday occurrence; otherwise
        # degrade to campaign-level source attribution rather than losing the
        # sale or recording a false cycle outcome.
        attributed_cycle_id = None
        if campaign is not None and cycle is not None:
            campaign_child_id = (campaign.destination_payload or {}).get('birthdayChildId')
            if (
                child is not None
                and child.birth_date is not None
                and (not campaign_child_id or campaign_child_id == child.id)
                and birthday_occurrence_for_year(child.birth_date, cycle.birthday_year) == cycle.target_date
            ):
                attributed_cycle_id = cycle.id
        elif campaign is None:
            attributed_cycle_id = self._match_cycle(
                mobile_user_id=mobile_user_id, child=child, requested_date=payload.preferredDate
            )

        branch = self.branch_repository.get_active_by_id_or_slug(payload.branchId)
        if branch is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Selected branch was not found.',
                details=[{'field': 'branchId', 'message': 'Selected branch was not found.'}],
            )

        package = None
        if payload.packageId:
            package = self.package_repository.get_active_by_id(payload.packageId)
            if package is None:
                raise NotFoundException(
                    code='package_not_found',
                    message='Selected package was not found.',
                    details=[{'field': 'packageId', 'message': 'Selected package was not found.'}],
                )
            if package.branch_id != branch.id:
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

        try:
            request = self.repository.create_birthday_lead(
                {
                    'mobile_user_id': mobile_user_id,
                    'branch_id': branch.id,
                    'birthday_package_id': payload.packageId,
                    'customer_name': payload.name,
                    'phone': payload.phone,
                    'requested_date': payload.preferredDate,
                    'guest_count': payload.guestCount,
                    'notes': payload.comment,
                    'child_id': child.id if child is not None else None,
                    'idempotency_key': payload.idempotencyKey,
                    'child_name_snapshot': child.name if child is not None else None,
                    'child_birth_date_snapshot': child.birth_date if child is not None else None,
                    'package_name_snapshot': package.name if package is not None else None,
                    'package_price_snapshot': package.price_from if package is not None else None,
                    'birthday_cycle_id': attributed_cycle_id,
                    'source_campaign_id': campaign.id if campaign is not None else None,
                    'source': 'birthday_crm' if campaign is not None else 'mobile_app',
                }
            )
        except IntegrityError:
            self.repository.db.rollback()
            if payload.idempotencyKey:
                existing = self.repository.get_birthday_lead_by_idempotency_key(
                    mobile_user_id=mobile_user_id,
                    idempotency_key=payload.idempotencyKey,
                )
                if existing is not None:
                    return self._response(existing)
            raise
        return self._response(request)

    def _match_cycle(self, *, mobile_user_id: str | None, child, requested_date):
        if not mobile_user_id or child is None or child.birth_date is None or requested_date is None:
            return None
        cycles = self.repository.db.scalars(select(BirthdayRevenueCycle).where(
            BirthdayRevenueCycle.mobile_user_id == mobile_user_id,
            BirthdayRevenueCycle.target_date == requested_date,
        )).all()
        for cycle in cycles:
            if birthday_occurrence_for_year(child.birth_date, cycle.birthday_year) == requested_date:
                return cycle.id
        return None

    @staticmethod
    def _response(request) -> BirthdayLeadSubmittedResponse:
        return BirthdayLeadSubmittedResponse(
            requestId=request.id,
            submittedAt=request.created_at,
            nextStep='Менеджер свяжется с вами для подтверждения деталей',
        )

    def list_birthday_leads(self, mobile_user_id: str) -> BirthdayLeadListResponse:
        items = [self._serialize_lead(item) for item in self.repository.list_birthday_leads_for_user(mobile_user_id)]
        return BirthdayLeadListResponse(items=items, total=len(items))

    def get_birthday_lead(self, lead_id: str, mobile_user_id: str) -> BirthdayLeadResponse:
        request = self.repository.get_birthday_lead_for_user(lead_id, mobile_user_id)
        if request is None:
            raise NotFoundException(code='birthday_lead_not_found', message='Birthday request was not found.')
        return self._serialize_lead(request)

    @staticmethod
    def _serialize_lead(request) -> BirthdayLeadResponse:
        return BirthdayLeadResponse(
            id=request.id,
            status=request.status,
            childId=request.child_id,
            childName=request.child_name_snapshot,
            childBirthDate=request.child_birth_date_snapshot,
            branchId=request.branch_id,
            packageId=request.birthday_package_id,
            packageName=request.package_name_snapshot,
            requestedDate=request.requested_date,
            guestCount=request.guest_count,
            comment=request.notes,
            createdAt=request.created_at,
            updatedAt=request.updated_at,
            contactedAt=request.contacted_at,
            closedAt=request.closed_at,
        )
