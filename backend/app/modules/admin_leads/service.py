from __future__ import annotations

from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.repositories.lead_inbox_repository import LeadInboxRecord, LeadInboxRepository
from ..leads.constants import LEAD_TYPE_BIRTHDAY_REQUEST, LEAD_TYPE_CONTACT
from .schemas import (
    AdminLeadBaseResponse,
    AdminLeadBranchSummary,
    AdminLeadDetailResponse,
    AdminLeadListQuery,
    AdminLeadListResponse,
    AdminLeadPackageSummary,
    AdminLeadStatusUpdateRequest,
    LeadInboxStatus,
)

LEAD_INBOX_ALLOWED_ROLES = (
    'super_admin',
    'operator',
    'content_manager',
    'sales_manager',
)

LEAD_STATUS_TRANSITIONS: dict[LeadInboxStatus, set[LeadInboxStatus]] = {
    'new': {'new', 'in_progress', 'closed'},
    'in_progress': {'in_progress', 'closed'},
    'closed': {'closed'},
}


class AdminLeadInboxService:
    def __init__(
        self,
        *,
        repository: LeadInboxRepository | None = None,
    ) -> None:
        self.repository = repository or LeadInboxRepository()

    def list_leads(self, filters: AdminLeadListQuery) -> AdminLeadListResponse:
        self._validate_filters(filters)
        records = self.repository.list_records(
            branch_id=filters.branchId,
            status=filters.status,
            created_from=filters.createdFrom,
            created_to=filters.createdTo,
        )
        return AdminLeadListResponse(
            items=[self._serialize_list_item(record) for record in records],
            total=len(records),
        )

    def get_lead(self, lead_id: str) -> AdminLeadDetailResponse:
        record = self.repository.get_record(lead_id)
        if record is None:
            raise NotFoundException(
                code='lead_not_found',
                message='Lead was not found.',
            )
        return self._serialize_detail(record)

    def update_lead_status(
        self,
        lead_id: str,
        payload: AdminLeadStatusUpdateRequest,
    ) -> AdminLeadDetailResponse:
        birthday_request = self.repository.get_birthday_request_entity(lead_id)
        contact_lead = None
        if birthday_request is None:
            contact_lead = self.repository.get_contact_lead_entity(lead_id)
        if birthday_request is None and contact_lead is None:
            raise NotFoundException(
                code='lead_not_found',
                message='Lead was not found.',
            )

        current_status = birthday_request.status if birthday_request is not None else contact_lead.status
        if current_status not in LEAD_STATUS_TRANSITIONS:
            raise DomainHTTPException(
                code='unsupported_lead_status',
                message='Lead status is not supported.',
                status_code=422,
                details=[
                    {
                        'field': 'status',
                        'message': 'Current lead status is not supported.',
                    }
                ],
            )

        if payload.status not in LEAD_STATUS_TRANSITIONS[current_status]:
            raise DomainHTTPException(
                code='invalid_lead_status_transition',
                message='Lead status transition is not allowed.',
                status_code=422,
                details=[
                    {
                        'field': 'status',
                        'message': (
                            f'Cannot change lead status from {current_status} '
                            f'to {payload.status}.'
                        ),
                    }
                ],
            )

        if payload.status != current_status:
            if birthday_request is not None:
                self.repository.update_birthday_request_status(
                    birthday_request,
                    status=payload.status,
                )
            else:
                self.repository.update_contact_lead_status(
                    contact_lead,
                    status=payload.status,
                )

        return self.get_lead(lead_id)

    def _validate_filters(self, filters: AdminLeadListQuery) -> None:
        if (
            filters.createdFrom is not None
            and filters.createdTo is not None
            and filters.createdFrom > filters.createdTo
        ):
            raise DomainHTTPException(
                code='invalid_filter_range',
                message='createdFrom must be earlier than or equal to createdTo.',
                status_code=422,
                details=[
                    {
                        'field': 'createdFrom',
                        'message': 'createdFrom must be earlier than or equal to createdTo.',
                    }
                ],
            )

    def _serialize_list_item(self, record: LeadInboxRecord) -> AdminLeadBaseResponse:
        return AdminLeadBaseResponse(
            id=record.id,
            type=record.type,
            summary=self._build_summary(record),
            status=record.status,
            source=record.source,
            customerName=record.customer_name,
            phone=record.phone,
            guestCount=record.guest_count,
            requestedDate=record.requested_date,
            createdAt=record.created_at,
            branch=self._serialize_branch(record),
            package=self._serialize_package(record),
        )

    def _serialize_detail(self, record: LeadInboxRecord) -> AdminLeadDetailResponse:
        return AdminLeadDetailResponse(
            **self._serialize_list_item(record).model_dump(),
            email=record.email,
            notes=record.notes,
            contactMethod=record.contact_method,
        )

    def _serialize_branch(self, record: LeadInboxRecord) -> AdminLeadBranchSummary | None:
        if (
            record.branch_id is None
            or record.branch_name is None
            or record.branch_short_label is None
        ):
            return None
        return AdminLeadBranchSummary(
            id=record.branch_id,
            name=record.branch_name,
            shortLabel=record.branch_short_label,
        )

    def _serialize_package(
        self,
        record: LeadInboxRecord,
    ) -> AdminLeadPackageSummary | None:
        if record.birthday_package_id is None or record.birthday_package_name is None:
            return None
        return AdminLeadPackageSummary(
            id=record.birthday_package_id,
            name=record.birthday_package_name,
        )

    def _build_summary(self, record: LeadInboxRecord) -> str:
        if record.type == LEAD_TYPE_BIRTHDAY_REQUEST:
            parts = ['Заявка на день рождения']
            branch_label = record.branch_short_label or record.branch_name
            if branch_label is not None:
                parts.append(branch_label)
            if record.birthday_package_name is not None:
                parts.append(record.birthday_package_name)
            return ' · '.join(parts)

        parts = ['Связь с менеджером']
        context = self._build_contact_context(record)
        if context is not None:
            parts.append(context)
        return ' · '.join(parts)

    def _build_contact_context(self, record: LeadInboxRecord) -> str | None:
        if record.type != LEAD_TYPE_CONTACT:
            return None

        if record.notes is not None:
            normalized_notes = ' '.join(record.notes.split())
            if normalized_notes:
                if len(normalized_notes) <= 96:
                    return normalized_notes
                return f'{normalized_notes[:93].rstrip()}...'

        if record.email is not None:
            normalized_email = record.email.strip()
            if normalized_email:
                return normalized_email

        return 'Без дополнительного контекста'
