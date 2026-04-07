from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime

from sqlalchemy import Select, func, select

from ..models.birthday_package import BirthdayPackage
from ..models.birthday_request import BirthdayRequest
from ..models.branch import Branch
from .base import Repository


@dataclass(frozen=True)
class LeadInboxRecord:
    id: str
    status: str
    source: str
    customer_name: str
    phone: str
    guest_count: int | None
    requested_date: date | None
    notes: str | None
    contact_method: str
    created_at: datetime
    branch_id: str
    branch_name: str
    branch_short_label: str
    birthday_package_id: str | None
    birthday_package_name: str | None


class LeadInboxRepository(Repository):
    def list_birthday_request_records(
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

    def get_birthday_request_entity(self, lead_id: str) -> BirthdayRequest | None:
        return self.db.scalar(
            select(BirthdayRequest).where(BirthdayRequest.id == lead_id)
        )

    def update_birthday_request_status(
        self,
        birthday_request: BirthdayRequest,
        *,
        status: str,
    ) -> BirthdayRequest:
        birthday_request.status = status
        self.db.add(birthday_request)
        self.db.commit()
        self.db.refresh(birthday_request)
        return birthday_request

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
            status=birthday_request.status,
            source=birthday_request.source,
            customer_name=birthday_request.customer_name,
            phone=birthday_request.phone,
            guest_count=birthday_request.guest_count,
            requested_date=birthday_request.requested_date,
            notes=birthday_request.notes,
            contact_method=birthday_request.contact_method,
            created_at=birthday_request.created_at,
            branch_id=branch.id,
            branch_name=branch.name,
            branch_short_label=branch.short_label,
            birthday_package_id=package.id if package else None,
            birthday_package_name=package.name if package else None,
        )
