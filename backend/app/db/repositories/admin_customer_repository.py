from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import Select, case, func, or_, select

from ..models.birthday_package import BirthdayPackage
from ..models.birthday_request import BirthdayRequest
from ..models.branch import Branch
from ..models.loyalty_account import LoyaltyAccount
from ..models.mobile_child import MobileChild
from ..models.mobile_payment import MobilePayment
from ..models.mobile_user import MobileUser
from ..models.visit import Visit
from ...modules.visit_segmentation import (
    VisitAudienceSegment,
    visit_segment_predicate,
    visit_stats_subquery,
)
from .base import Repository


@dataclass(frozen=True)
class CustomerListRecord:
    user: MobileUser
    children_count: int
    visits_count: int
    first_visit_at: datetime | None
    last_visit_at: datetime | None
    ticket_cash_spend_tenge: int
    bonus_balance: int


@dataclass(frozen=True)
class CustomerVisitRecord:
    visit: Visit
    branch: Branch | None


@dataclass(frozen=True)
class CustomerPaymentRecord:
    payment: MobilePayment
    branch: Branch | None


@dataclass(frozen=True)
class CustomerBirthdayLeadRecord:
    request: BirthdayRequest
    branch: Branch | None
    package: BirthdayPackage | None


class AdminCustomerRepository(Repository):
    def list_customers(
        self,
        *,
        search: str | None,
        page: int,
        page_size: int,
        visit_segment: VisitAudienceSegment | None = None,
        now: datetime | None = None,
    ) -> tuple[list[CustomerListRecord], int]:
        child_counts = (
            select(
                MobileChild.user_id.label('user_id'),
                func.count(MobileChild.id).label('children_count'),
            )
            .group_by(MobileChild.user_id)
            .subquery()
        )
        visit_stats = visit_stats_subquery()
        payment_stats = (
            select(
                MobilePayment.mobile_user_id.label('user_id'),
                func.coalesce(func.sum(MobilePayment.cash_amount_tenge), 0).label(
                    'ticket_cash_spend_tenge'
                ),
            )
            .where(
                MobilePayment.status == 'paid',
                MobilePayment.payable_entity_type == 'branch_ticket_order',
            )
            .group_by(MobilePayment.mobile_user_id)
            .subquery()
        )

        conditions = self._customer_search_conditions(search)
        first_visit_at = visit_stats.c.first_visit_at
        last_visit_at = visit_stats.c.last_visit_at
        conditions = [*conditions]
        if visit_segment is not None:
            conditions.append(visit_segment_predicate(visit_stats, visit_segment, now or datetime.now(UTC)))

        count_statement = select(func.count(MobileUser.id)).outerjoin(
            visit_stats, visit_stats.c.user_id == MobileUser.id
        )
        if conditions:
            count_statement = count_statement.where(*conditions)
        total = int(self.db.scalar(count_statement) or 0)

        statement: Select[tuple[MobileUser, int | None, int | None, datetime | None, datetime | None, int | None, int | None]] = (
            select(
                MobileUser,
                child_counts.c.children_count,
                visit_stats.c.visit_count,
                first_visit_at,
                last_visit_at,
                payment_stats.c.ticket_cash_spend_tenge,
                LoyaltyAccount.balance,
            )
            .outerjoin(child_counts, child_counts.c.user_id == MobileUser.id)
            .outerjoin(visit_stats, visit_stats.c.user_id == MobileUser.id)
            .outerjoin(payment_stats, payment_stats.c.user_id == MobileUser.id)
            .outerjoin(LoyaltyAccount, LoyaltyAccount.mobile_user_id == MobileUser.id)
        )
        if conditions:
            statement = statement.where(*conditions)

        rows = self.db.execute(
            statement
            .order_by(
                case((last_visit_at.is_(None), 1), else_=0),
                last_visit_at.desc(),
                MobileUser.created_at.desc(),
                MobileUser.id.asc(),
            )
            .offset((page - 1) * page_size)
            .limit(page_size)
        ).all()
        return (
            [
                CustomerListRecord(
                    user=user,
                    children_count=int(children_count or 0),
                    visits_count=int(visits_count or 0),
                    first_visit_at=first_visit,
                    last_visit_at=last_visit,
                    ticket_cash_spend_tenge=int(ticket_cash_spend or 0),
                    bonus_balance=int(balance or 0),
                )
                for user, children_count, visits_count, first_visit, last_visit, ticket_cash_spend, balance in rows
            ],
            total,
        )

    def get_user(self, customer_id: str) -> MobileUser | None:
        return self.db.scalar(select(MobileUser).where(MobileUser.id == customer_id))

    def list_children(self, customer_id: str) -> list[MobileChild]:
        return list(
            self.db.scalars(
                select(MobileChild)
                .where(MobileChild.user_id == customer_id)
                .order_by(MobileChild.created_at.asc(), MobileChild.id.asc())
            ).all()
        )

    def get_visit_stats(self, customer_id: str) -> tuple[int, datetime | None, datetime | None]:
        row = self.db.execute(
            select(
                func.count(Visit.id),
                func.min(Visit.started_at),
                func.max(Visit.started_at),
            ).where(Visit.mobile_user_id == customer_id)
        ).one()
        visits_count, first_visit_at, last_visit_at = row
        return int(visits_count or 0), first_visit_at, last_visit_at

    def list_visits(self, customer_id: str, *, limit: int) -> list[CustomerVisitRecord]:
        rows = self.db.execute(
            select(Visit, Branch)
            .outerjoin(Branch, Branch.id == Visit.branch_id)
            .where(Visit.mobile_user_id == customer_id)
            .order_by(Visit.started_at.desc(), Visit.id.desc())
            .limit(limit)
        ).all()
        return [CustomerVisitRecord(visit=visit, branch=branch) for visit, branch in rows]

    def list_ticket_payments(self, customer_id: str, *, limit: int) -> list[CustomerPaymentRecord]:
        rows = self.db.execute(
            select(MobilePayment, Branch)
            .outerjoin(Branch, Branch.id == MobilePayment.branch_id)
            .where(
                MobilePayment.mobile_user_id == customer_id,
                MobilePayment.payable_entity_type == 'branch_ticket_order',
            )
            .order_by(MobilePayment.paid_at.desc(), MobilePayment.created_at.desc(), MobilePayment.id.desc())
            .limit(limit)
        ).all()
        return [CustomerPaymentRecord(payment=payment, branch=branch) for payment, branch in rows]

    def get_loyalty_account(self, customer_id: str) -> LoyaltyAccount | None:
        return self.db.scalar(
            select(LoyaltyAccount).where(LoyaltyAccount.mobile_user_id == customer_id)
        )

    def list_birthday_leads(self, customer_id: str) -> list[CustomerBirthdayLeadRecord]:
        rows = self.db.execute(
            select(BirthdayRequest, Branch, BirthdayPackage)
            .outerjoin(Branch, Branch.id == BirthdayRequest.branch_id)
            .outerjoin(BirthdayPackage, BirthdayPackage.id == BirthdayRequest.birthday_package_id)
            .where(BirthdayRequest.mobile_user_id == customer_id)
            .order_by(BirthdayRequest.created_at.desc(), BirthdayRequest.id.desc())
        ).all()
        return [
            CustomerBirthdayLeadRecord(request=request, branch=branch, package=package)
            for request, branch, package in rows
        ]

    def _customer_search_conditions(self, search: str | None):
        raw = (search or '').strip()
        if not raw:
            return []
        normalized = raw.lower()
        escaped_raw = raw.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
        escaped_normalized = normalized.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
        raw_pattern = f'%{escaped_raw}%'
        normalized_pattern = f'%{escaped_normalized}%'
        return [
            or_(
                func.lower(func.coalesce(MobileUser.first_name, '')).like(normalized_pattern, escape='\\'),
                func.lower(func.coalesce(MobileUser.last_name, '')).like(normalized_pattern, escape='\\'),
                func.lower(func.coalesce(MobileUser.phone, '')).like(normalized_pattern, escape='\\'),
                func.lower(func.coalesce(MobileUser.email, '')).like(normalized_pattern, escape='\\'),
                MobileUser.first_name.like(raw_pattern, escape='\\'),
                MobileUser.last_name.like(raw_pattern, escape='\\'),
                MobileUser.phone.like(raw_pattern, escape='\\'),
                MobileUser.email.like(raw_pattern, escape='\\'),
            )
        ]
