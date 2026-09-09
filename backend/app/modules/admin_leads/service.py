from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from math import ceil
from statistics import median
from typing import Callable

from ...core.time.business_time import BUSINESS_TIMEZONE
from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.repositories.lead_inbox_repository import LeadInboxRecord, LeadInboxRepository
from ..leads.constants import LEAD_TYPE_BIRTHDAY_REQUEST, LEAD_TYPE_CONTACT, LOST_REASONS
from .schemas import (
    AdminLeadBaseResponse,
    AdminLeadBranchSummary,
    AdminLeadDetailResponse,
    AdminBirthdayLeadDetailResponse,
    AdminLeadListQuery,
    AdminLeadListResponse,
    AdminLeadPackageSummary,
    AdminLeadStatusUpdateRequest,
    AdminBirthdayOperationsSummaryResponse,
    LeadInboxStatus,
    OwnerDashboardPeriod,
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

BIRTHDAY_STATUS_TRANSITIONS: dict[LeadInboxStatus, set[LeadInboxStatus]] = {
    'new': {'new', 'contacted', 'confirmed', 'cancelled', 'in_progress', 'closed', 'lost'},
    'contacted': {'contacted', 'qualified', 'confirmed', 'cancelled', 'lost'},
    'qualified': {'qualified', 'booked', 'lost'},
    'booked': {'booked', 'paid', 'completed', 'lost'},
    'paid': {'paid', 'completed', 'lost'},
    'completed': {'completed'},
    'confirmed': {'confirmed', 'paid', 'completed', 'lost'},
    'cancelled': {'cancelled'},
    # A lost lead can be reopened when the parent comes back. Historical
    # lost_at remains an audit timestamp; current lost_reason is cleared.
    'lost': {'lost', 'contacted', 'qualified'},
    # Legacy values remain readable and safely terminal/forward-compatible.
    'in_progress': {'in_progress', 'contacted', 'qualified', 'booked', 'confirmed', 'cancelled', 'lost', 'closed'},
    'closed': {'closed'},
}


class AdminLeadInboxService:
    def __init__(
        self,
        *,
        repository: LeadInboxRepository | None = None,
        now_provider: Callable[[], datetime] | None = None,
    ) -> None:
        self.repository = repository or LeadInboxRepository()
        self.now_provider = now_provider or (lambda: datetime.now(UTC))

    def list_leads(self, filters: AdminLeadListQuery) -> AdminLeadListResponse:
        self._validate_filters(filters)
        records = self.repository.list_records(
            branch_id=filters.branchId,
            status=filters.status,
            created_from=filters.createdFrom,
            created_to=filters.createdTo,
            awaiting_contact=filters.awaitingContact,
            sort=filters.sort,
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

    def get_birthday_lead_detail(self, lead_id: str) -> AdminBirthdayLeadDetailResponse:
        record = self.repository.get_record(lead_id)
        if record is None or record.type != LEAD_TYPE_BIRTHDAY_REQUEST:
            raise NotFoundException(code='birthday_lead_not_found', message='Birthday request was not found.')
        return AdminBirthdayLeadDetailResponse(
            id=record.id,
            status=record.status,
            source=record.source,
            customerName=record.customer_name,
            phone=record.phone,
            contactMethod=record.contact_method,
            childId=record.child_id,
            childName=record.child_name,
            childBirthDate=record.child_birth_date,
            requestedDate=record.requested_date,
            guestCount=record.guest_count,
            branch=self._serialize_branch(record),
            package=self._serialize_package(record),
            packageNameSnapshot=(
                record.birthday_package_snapshot_name
                if record.birthday_package_snapshot_name is not None
                else record.birthday_package_name
            ),
            packagePriceSnapshot=(
                record.birthday_package_snapshot_price
                if record.birthday_package_snapshot_price is not None
                else record.birthday_package_price
            ),
            agreedAmountTenge=record.agreed_amount_tenge,
            expectedAmountTenge=record.expected_amount_tenge,
            depositAmountTenge=record.deposit_amount_tenge,
            paidAmountTenge=record.paid_amount_tenge,
            lostReason=record.lost_reason,
            comment=record.notes,
            adminNote=record.admin_note,
            createdAt=record.created_at,
            waitingForContactMinutes=self._waiting_for_contact_minutes(record),
            firstContactMinutes=self._first_contact_minutes(record),
            updatedAt=record.updated_at,
            contactedAt=record.contacted_at,
            qualifiedAt=record.qualified_at,
            bookedAt=record.booked_at,
            completedAt=record.completed_at,
            lostAt=record.lost_at,
            closedAt=record.closed_at,
            paidAt=record.paid_at,
        )

    def get_birthday_operations_summary(
        self,
        period: OwnerDashboardPeriod,
    ) -> AdminBirthdayOperationsSummaryResponse:
        now = self._normalize_now(self.now_provider())
        period_start = self._period_start(period, now)
        waiting_count, oldest_waiting_created_at, period_rows = self.repository.list_birthday_operations_rows(
            period_start=period_start.astimezone(UTC),
            period_end=now,
        )
        contacted_period_rows = [
            (created_at, contacted_at)
            for created_at, contacted_at in period_rows
            if contacted_at is not None
            and self._normalize_now(contacted_at) >= self._normalize_now(created_at)
        ]
        response_minutes = [
            self._elapsed_minutes(created_at, contacted_at)
            for created_at, contacted_at in contacted_period_rows
        ]
        return AdminBirthdayOperationsSummaryResponse(
            period=period,
            periodStart=period_start,
            periodEnd=now,
            timezone=BUSINESS_TIMEZONE.key,
            newAwaitingContact=waiting_count,
            oldestWaitingMinutes=(
                self._elapsed_minutes(oldest_waiting_created_at, now)
                if oldest_waiting_created_at is not None
                else None
            ),
            leadsCreated=len(period_rows),
            contactedFromCreatedLeads=len(response_minutes),
            medianFirstContactMinutes=(int(median(response_minutes)) if response_minutes else None),
            p90FirstContactMinutes=self._p90(response_minutes),
        )

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
        transitions = BIRTHDAY_STATUS_TRANSITIONS if birthday_request is not None else LEAD_STATUS_TRANSITIONS
        if current_status not in transitions:
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

        if payload.status not in transitions[current_status]:
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

        if birthday_request is not None:
            if payload.status == 'lost':
                reason = payload.lostReason or birthday_request.lost_reason
                if reason not in LOST_REASONS:
                    raise DomainHTTPException(
                        code='lost_reason_required',
                        message='Select a reason for the lost lead.',
                        status_code=422,
                        details=[
                            {
                                'field': 'lostReason',
                                'message': 'A valid lost reason is required.',
                            }
                        ],
                    )
            elif payload.lostReason is not None:
                raise DomainHTTPException(
                    code='lost_reason_only_for_lost',
                    message='Lost reason can only be set for a lost lead.',
                    status_code=422,
                    details=[{'field': 'lostReason', 'message': 'Use lost status first.'}],
                )
            if payload.expectedAmountTenge is not None and payload.agreedAmountTenge is not None:
                if payload.expectedAmountTenge != payload.agreedAmountTenge:
                    raise DomainHTTPException(
                        code='conflicting_expected_amount',
                        message='Use one expected amount value.',
                        status_code=422,
                        details=[{'field': 'expectedAmountTenge', 'message': 'Values must match.'}],
                    )
            expected_amount = (
                payload.expectedAmountTenge
                if payload.expectedAmountTenge is not None
                else payload.agreedAmountTenge
            )
            current_paid = birthday_request.paid_amount_tenge
            next_paid = payload.paidAmountTenge if payload.paidAmountTenge is not None else current_paid
            next_deposit = (
                payload.depositAmountTenge
                if payload.depositAmountTenge is not None
                else birthday_request.deposit_amount_tenge
            )
            if next_deposit is not None and next_paid is not None and next_deposit > next_paid:
                raise DomainHTTPException(
                    code='deposit_exceeds_paid_amount',
                    message='Deposit cannot exceed total received amount.',
                    status_code=422,
                    details=[{'field': 'depositAmountTenge', 'message': 'Must be less than or equal to paid amount.'}],
                )
            if payload.status == 'paid' and next_paid is None:
                raise DomainHTTPException(
                    code='paid_amount_required',
                    message='Paid amount is required before marking a lead as paid.',
                    status_code=422,
                    details=[{'field': 'paidAmountTenge', 'message': 'Enter the amount received.'}],
                )
        else:
            expected_amount = None

        if payload.status != current_status:
            if birthday_request is not None:
                self.repository.update_birthday_request_status(
                    birthday_request,
                    status=payload.status,
                    agreed_amount_tenge=payload.agreedAmountTenge,
                    expected_amount_tenge=expected_amount,
                    deposit_amount_tenge=payload.depositAmountTenge,
                    paid_amount_tenge=payload.paidAmountTenge,
                    lost_reason=payload.lostReason,
                )
            else:
                self.repository.update_contact_lead_status(
                    contact_lead,
                    status=payload.status,
                )
        elif birthday_request is not None and (
            payload.agreedAmountTenge is not None
            or payload.expectedAmountTenge is not None
            or payload.depositAmountTenge is not None
            or payload.paidAmountTenge is not None
            or payload.lostReason is not None
        ):
            self.repository.update_birthday_request_status(
                birthday_request,
                status=current_status,
                agreed_amount_tenge=payload.agreedAmountTenge,
                expected_amount_tenge=expected_amount,
                deposit_amount_tenge=payload.depositAmountTenge,
                paid_amount_tenge=payload.paidAmountTenge,
                lost_reason=payload.lostReason or birthday_request.lost_reason,
            )

        if birthday_request is not None and payload.adminNote is not None:
            self.repository.update_birthday_request_note(
                birthday_request,
                admin_note=payload.adminNote,
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
            waitingForContactMinutes=self._waiting_for_contact_minutes(record),
            firstContactMinutes=self._first_contact_minutes(record),
            branch=self._serialize_branch(record),
            package=self._serialize_package(record),
        )

    def _waiting_for_contact_minutes(self, record: LeadInboxRecord) -> int | None:
        if (
            record.type != LEAD_TYPE_BIRTHDAY_REQUEST
            or record.status != 'new'
            or record.contacted_at is not None
        ):
            return None
        return self._elapsed_minutes(record.created_at, self._normalize_now(self.now_provider()))

    def _first_contact_minutes(self, record: LeadInboxRecord) -> int | None:
        if record.type != LEAD_TYPE_BIRTHDAY_REQUEST or record.contacted_at is None:
            return None
        return self._elapsed_minutes(record.created_at, record.contacted_at)

    @staticmethod
    def _period_start(period: OwnerDashboardPeriod, now: datetime) -> datetime:
        days_back = {
            OwnerDashboardPeriod.TODAY: 0,
            OwnerDashboardPeriod.SEVEN_DAYS: 6,
            OwnerDashboardPeriod.THIRTY_DAYS: 29,
        }[period]
        local_today = now.astimezone(BUSINESS_TIMEZONE).date()
        return datetime.combine(
            local_today - timedelta(days=days_back),
            time.min,
            tzinfo=BUSINESS_TIMEZONE,
        )

    @staticmethod
    def _normalize_now(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)

    @classmethod
    def _elapsed_minutes(cls, start: datetime, end: datetime) -> int:
        start_utc = cls._normalize_now(start)
        end_utc = cls._normalize_now(end)
        return max(0, int((end_utc - start_utc).total_seconds() // 60))

    @staticmethod
    def _p90(values: list[int]) -> int | None:
        if not values:
            return None
        ordered = sorted(values)
        index = max(0, min(len(ordered) - 1, ceil(len(ordered) * 0.9) - 1))
        return ordered[index]

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
            if record.requested_date is not None:
                parts.append(self._format_requested_date(record.requested_date))
            if record.guest_count is not None:
                parts.append(self._format_guest_count(record.guest_count))
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

        normalized_phone = record.phone.strip()
        if normalized_phone:
            return normalized_phone

        normalized_name = record.customer_name.strip()
        if normalized_name:
            return normalized_name

        return 'Без дополнительного контекста'

    def _format_requested_date(self, value: date) -> str:
        return value.strftime('%d.%m.%Y')

    def _format_guest_count(self, value: int) -> str:
        if value % 10 == 1 and value % 100 != 11:
            return f'{value} гость'
        if value % 10 in {2, 3, 4} and value % 100 not in {12, 13, 14}:
            return f'{value} гостя'
        return f'{value} гостей'
