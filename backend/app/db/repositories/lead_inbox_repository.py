from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime

from sqlalchemy import Select, func, select

from ..models.birthday_package import BirthdayPackage
from ..models.birthday_request import BirthdayRequest
from ..models.branch import Branch
from ..models.contact_lead import ContactLead
from ...modules.leads.constants import LEAD_TYPE_BIRTHDAY_REQUEST, LEAD_TYPE_CONTACT
from .base import Repository


@dataclass(frozen=True)
class LeadInboxRecord:
    id: str
    type: str
    status: str
    source: str
    customer_name: str
    phone: str
    email: str | None
    guest_count: int | None
    requested_date: date | None
    notes: str | None
    contact_method: str
    created_at: datetime
    branch_id: str | None
    branch_name: str | None
    branch_short_label: str | None
    birthday_package_id: str | None
    birthday_package_name: str | None
    birthday_package_price: int | None
    birthday_package_snapshot_name: str | None
    birthday_package_snapshot_price: int | None
    child_id: str | None
    child_name: str | None
    child_birth_date: date | None
    admin_note: str | None
    updated_at: datetime
    contacted_at: datetime | None
    closed_at: datetime | None


class LeadInboxRepository(Repository):
    def list_records(
        self,
        *,
        branch_id: str | None = None,
        status: str | None = None,
        created_from: date | None = None,
        created_to: date | None = None,
    ) -> list[LeadInboxRecord]:
        records = self._list_birthday_request_records(
            branch_id=branch_id,
            status=status,
            created_from=created_from,
            created_to=created_to,
        )
        if branch_id is None:
            records.extend(
                self._list_contact_records(
                    status=status,
                    created_from=created_from,
                    created_to=created_to,
                )
            )
        return sorted(records, key=lambda record: record.created_at, reverse=True)

    def get_record(self, lead_id: str) -> LeadInboxRecord | None:
        birthday_record = self.get_birthday_request_record(lead_id)
        if birthday_record is not None:
            return birthday_record
        return self.get_contact_record(lead_id)

    def _list_birthday_request_records(
        self,
        *,
        branch_id: str | None = None,
        status: str | None = None,
        created_from: date | None = None,
        created_to: date | None = None,
    ) -> list[LeadInboxRecord]:
        statement = self._build_record_query()

        if branch_id:
            statement = statement.where(BirthdayRequest.branch_id == branch_id)
        if status:
            statement = statement.where(BirthdayRequest.status == status)
        if created_from:
            statement = statement.where(func.date(BirthdayRequest.created_at) >= created_from)
        if created_to:
            statement = statement.where(func.date(BirthdayRequest.created_at) <= created_to)

        rows = self.db.execute(statement.order_by(BirthdayRequest.created_at.desc())).all()
        return [self._map_record(row) for row in rows]

    def get_birthday_request_record(self, lead_id: str) -> LeadInboxRecord | None:
        row = self.db.execute(
            self._build_record_query().where(BirthdayRequest.id == lead_id)
        ).one_or_none()
        if row is None:
            return None
        return self._map_record(row)

    def _list_contact_records(
        self,
        *,
        status: str | None = None,
        created_from: date | None = None,
        created_to: date | None = None,
    ) -> list[LeadInboxRecord]:
        statement = select(ContactLead)
        if status:
            statement = statement.where(ContactLead.status == status)
        if created_from:
            statement = statement.where(func.date(ContactLead.created_at) >= created_from)
        if created_to:
            statement = statement.where(func.date(ContactLead.created_at) <= created_to)

        rows = self.db.scalars(statement.order_by(ContactLead.created_at.desc())).all()
        return [self._map_contact_record(row) for row in rows]

    def get_contact_record(self, lead_id: str) -> LeadInboxRecord | None:
        lead = self.db.scalar(select(ContactLead).where(ContactLead.id == lead_id))
        if lead is None:
            return None
        return self._map_contact_record(lead)

    def get_birthday_request_entity(self, lead_id: str) -> BirthdayRequest | None:
        return self.db.scalar(
            select(BirthdayRequest).where(BirthdayRequest.id == lead_id)
        )

    def get_contact_lead_entity(self, lead_id: str) -> ContactLead | None:
        return self.db.scalar(
            select(ContactLead).where(ContactLead.id == lead_id)
        )

    def update_birthday_request_status(
        self,
        birthday_request: BirthdayRequest,
        *,
        status: str,
    ) -> BirthdayRequest:
        birthday_request.status = status
        now = datetime.now(UTC)
        birthday_request.updated_at = now
        if status in {'contacted', 'in_progress'} and birthday_request.contacted_at is None:
            birthday_request.contacted_at = now
        if status in {'confirmed', 'cancelled', 'lost', 'closed'}:
            birthday_request.closed_at = birthday_request.closed_at or now
        self.db.add(birthday_request)
        self.db.commit()
        self.db.refresh(birthday_request)
        return birthday_request

    def update_birthday_request_note(
        self, birthday_request: BirthdayRequest, *, admin_note: str | None
    ) -> BirthdayRequest:
        birthday_request.admin_note = admin_note.strip() if admin_note else None
        birthday_request.updated_at = datetime.now(UTC)
        self.db.add(birthday_request)
        self.db.commit()
        self.db.refresh(birthday_request)
        return birthday_request

    def update_contact_lead_status(
        self,
        contact_lead: ContactLead,
        *,
        status: str,
    ) -> ContactLead:
        contact_lead.status = status
        self.db.add(contact_lead)
        self.db.commit()
        self.db.refresh(contact_lead)
        return contact_lead

    def _build_record_query(self) -> Select[tuple[BirthdayRequest, Branch, BirthdayPackage | None]]:
        return (
            select(BirthdayRequest, Branch, BirthdayPackage)
            .join(Branch, BirthdayRequest.branch_id == Branch.id)
            .outerjoin(
                BirthdayPackage,
                BirthdayRequest.birthday_package_id == BirthdayPackage.id,
            )
        )

    def _map_record(self, row: tuple[BirthdayRequest, Branch, BirthdayPackage | None]) -> LeadInboxRecord:
        birthday_request, branch, package = row
        return LeadInboxRecord(
            id=birthday_request.id,
            type=LEAD_TYPE_BIRTHDAY_REQUEST,
            status=birthday_request.status,
            source=birthday_request.source,
            customer_name=birthday_request.customer_name,
            phone=birthday_request.phone,
            email=None,
            guest_count=birthday_request.guest_count,
            requested_date=birthday_request.requested_date,
            notes=birthday_request.notes,
            contact_method=birthday_request.contact_method,
            created_at=birthday_request.created_at,
            branch_id=branch.id,
            branch_name=branch.name,
            branch_short_label=branch.short_label,
            birthday_package_id=package.id if package else None,
            birthday_package_name=(package.name if package else birthday_request.package_name_snapshot),
            birthday_package_price=(package.price_from if package else birthday_request.package_price_snapshot),
            birthday_package_snapshot_name=birthday_request.package_name_snapshot,
            birthday_package_snapshot_price=birthday_request.package_price_snapshot,
            child_id=birthday_request.child_id,
            child_name=birthday_request.child_name_snapshot,
            child_birth_date=birthday_request.child_birth_date_snapshot,
            admin_note=birthday_request.admin_note,
            updated_at=birthday_request.updated_at,
            contacted_at=birthday_request.contacted_at,
            closed_at=birthday_request.closed_at,
        )

    def _map_contact_record(self, lead: ContactLead) -> LeadInboxRecord:
        return LeadInboxRecord(
            id=lead.id,
            type=LEAD_TYPE_CONTACT,
            status=lead.status,
            source=lead.source,
            customer_name=lead.customer_name,
            phone=lead.phone,
            email=lead.email,
            guest_count=None,
            requested_date=None,
            notes=lead.message,
            contact_method='phone',
            created_at=lead.created_at,
            branch_id=None,
            branch_name=None,
            branch_short_label=None,
            birthday_package_id=None,
            birthday_package_name=None,
            birthday_package_price=None,
            birthday_package_snapshot_name=None,
            birthday_package_snapshot_price=None,
            child_id=None,
            child_name=None,
            child_birth_date=None,
            admin_note=None,
            updated_at=lead.created_at,
            contacted_at=None,
            closed_at=None,
        )
