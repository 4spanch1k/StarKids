from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime

from sqlalchemy import select

from ..models.birthday_package import BirthdayPackage
from ..models.birthday_request import BirthdayRequest
from ..models.branch import Branch
from ..models.contact_lead import ContactLead
from ...modules.leads.constants import LEAD_TYPE_BIRTHDAY_REQUEST, LEAD_TYPE_CONTACT
from .base import Repository


@dataclass(frozen=True)
class MobileRequestHistoryRecord:
    id: str
    type: str
    status: str
    created_at: datetime
    requested_date: date | None
    guest_count: int | None
    notes: str | None
    branch_id: str | None
    branch_name: str | None
    branch_short_label: str | None
    birthday_package_id: str | None
    birthday_package_name: str | None


class MobileRequestHistoryRepository(Repository):
    def list_for_mobile_user(self, mobile_user_id: str) -> list[MobileRequestHistoryRecord]:
        records = self._list_birthday_records(mobile_user_id)
        records.extend(self._list_contact_records(mobile_user_id))
        return sorted(records, key=lambda record: record.created_at, reverse=True)

    def _list_birthday_records(self, mobile_user_id: str) -> list[MobileRequestHistoryRecord]:
        rows = self.db.execute(
            select(BirthdayRequest, Branch, BirthdayPackage)
            .join(Branch, BirthdayRequest.branch_id == Branch.id)
            .outerjoin(
                BirthdayPackage,
                BirthdayRequest.birthday_package_id == BirthdayPackage.id,
            )
            .where(BirthdayRequest.mobile_user_id == mobile_user_id)
            .order_by(BirthdayRequest.created_at.desc())
        ).all()
        return [self._map_birthday_record(row) for row in rows]

    def _list_contact_records(self, mobile_user_id: str) -> list[MobileRequestHistoryRecord]:
        leads = self.db.scalars(
            select(ContactLead)
            .where(ContactLead.mobile_user_id == mobile_user_id)
            .order_by(ContactLead.created_at.desc())
        ).all()
        return [self._map_contact_record(lead) for lead in leads]

    def _map_birthday_record(
        self,
        row: tuple[BirthdayRequest, Branch, BirthdayPackage | None],
    ) -> MobileRequestHistoryRecord:
        request, branch, package = row
        return MobileRequestHistoryRecord(
            id=request.id,
            type=LEAD_TYPE_BIRTHDAY_REQUEST,
            status=request.status,
            created_at=request.created_at,
            requested_date=request.requested_date,
            guest_count=request.guest_count,
            notes=request.notes,
            branch_id=branch.id,
            branch_name=branch.name,
            branch_short_label=branch.short_label,
            birthday_package_id=package.id if package is not None else None,
            birthday_package_name=package.name if package is not None else None,
        )

    def _map_contact_record(self, lead: ContactLead) -> MobileRequestHistoryRecord:
        return MobileRequestHistoryRecord(
            id=lead.id,
            type=LEAD_TYPE_CONTACT,
            status=lead.status,
            created_at=lead.created_at,
            requested_date=None,
            guest_count=None,
            notes=lead.message,
            branch_id=None,
            branch_name=None,
            branch_short_label=None,
            birthday_package_id=None,
            birthday_package_name=None,
        )
