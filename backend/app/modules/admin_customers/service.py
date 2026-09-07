from __future__ import annotations

from ...core.exceptions.http import NotFoundException
from ...db.repositories.admin_customer_repository import AdminCustomerRepository
from .schemas import (
    AdminCustomerBirthdayLeadResponse,
    AdminCustomerBranchResponse,
    AdminCustomerChildResponse,
    AdminCustomerDetailResponse,
    AdminCustomerListItem,
    AdminCustomerListQuery,
    AdminCustomerListResponse,
    AdminCustomerLoyaltyResponse,
    AdminCustomerMetricsResponse,
    AdminCustomerResponse,
    AdminCustomerTicketPurchaseResponse,
    AdminCustomerVisitResponse,
)


class AdminCustomerService:
    def __init__(self, *, repository: AdminCustomerRepository) -> None:
        self.repository = repository

    def list_customers(self, query: AdminCustomerListQuery) -> AdminCustomerListResponse:
        records, total = self.repository.list_customers(
            search=query.search,
            page=query.page,
            page_size=query.pageSize,
        )
        return AdminCustomerListResponse(
            items=[
                AdminCustomerListItem(
                    id=record.user.id,
                    firstName=record.user.first_name,
                    lastName=record.user.last_name,
                    phone=record.user.phone,
                    email=record.user.email,
                    childrenCount=record.children_count,
                    visitsCount=record.visits_count,
                    lastVisitAt=record.last_visit_at,
                    ticketCashSpendTenge=record.ticket_cash_spend_tenge,
                    bonusBalance=record.bonus_balance,
                    createdAt=record.user.created_at,
                )
                for record in records
            ],
            total=total,
            page=query.page,
            pageSize=query.pageSize,
        )

    def get_customer(self, customer_id: str) -> AdminCustomerDetailResponse:
        user = self.repository.get_user(customer_id)
        if user is None:
            raise NotFoundException(code='customer_not_found', message='Customer was not found.')

        children = self.repository.list_children(user.id)
        visits_count, first_visit_at, last_visit_at = self.repository.get_visit_stats(user.id)
        payments = self.repository.list_ticket_payments(user.id, limit=20)
        visits = self.repository.list_visits(user.id, limit=20)
        leads = self.repository.list_birthday_leads(user.id)
        loyalty_account = self.repository.get_loyalty_account(user.id)

        return AdminCustomerDetailResponse(
            customer=AdminCustomerResponse(
                id=user.id,
                firstName=user.first_name,
                lastName=user.last_name,
                phone=user.phone,
                email=user.email,
                isActive=user.is_active,
                createdAt=user.created_at,
            ),
            metrics=AdminCustomerMetricsResponse(
                childrenCount=len(children),
                visitsCount=visits_count,
                firstVisitAt=first_visit_at,
                lastVisitAt=last_visit_at,
                ticketCashSpendTenge=self._ticket_cash_spend(user.id),
            ),
            loyalty=AdminCustomerLoyaltyResponse(
                balance=int(loyalty_account.balance) if loyalty_account else 0,
                lifetimeEarned=int(loyalty_account.lifetime_earned) if loyalty_account else 0,
                lifetimeSpent=int(loyalty_account.lifetime_spent) if loyalty_account else 0,
            ),
            children=[
                AdminCustomerChildResponse(
                    id=child.id,
                    name=child.name,
                    birthDate=child.birth_date,
                    gender=child.gender,
                    createdAt=child.created_at,
                )
                for child in children
            ],
            recentVisits=[
                AdminCustomerVisitResponse(
                    id=record.visit.id,
                    branch=self._branch(record.branch),
                    status=record.visit.status,
                    startedAt=record.visit.started_at,
                    endedAt=record.visit.ended_at,
                )
                for record in visits
            ],
            recentTicketPurchases=[
                AdminCustomerTicketPurchaseResponse(
                    id=record.payment.id,
                    localOrderId=record.payment.local_order_id,
                    branch=self._branch(record.branch),
                    paidAt=record.payment.paid_at,
                    visitDate=record.payment.visit_date,
                    quantity=record.payment.quantity,
                    grossAmountTenge=record.payment.gross_amount_tenge,
                    bonusAmount=record.payment.bonus_amount,
                    cashAmountTenge=record.payment.cash_amount_tenge,
                    currency=record.payment.currency,
                    status=record.payment.status,
                )
                for record in payments
            ],
            birthdayLeads=[
                AdminCustomerBirthdayLeadResponse(
                    id=record.request.id,
                    childName=(
                        record.request.child_name_snapshot
                        or record.request.child_name
                    ),
                    childBirthDate=record.request.child_birth_date_snapshot,
                    desiredDate=record.request.requested_date,
                    branch=self._branch(record.branch),
                    packageName=(
                        record.request.package_name_snapshot
                        or (record.package.name if record.package else None)
                    ),
                    status=record.request.status,
                    createdAt=record.request.created_at,
                )
                for record in leads
            ],
        )

    def _ticket_cash_spend(self, customer_id: str) -> int:
        # The list endpoint already uses an aggregate subquery. Detail uses a
        # bounded purchase list for display, so calculate the full total with
        # one independent aggregate rather than joining children/visits.
        from sqlalchemy import func, select

        from ...db.models.mobile_payment import MobilePayment

        value = self.repository.db.scalar(
            select(func.coalesce(func.sum(MobilePayment.cash_amount_tenge), 0)).where(
                MobilePayment.mobile_user_id == customer_id,
                MobilePayment.status == 'paid',
                MobilePayment.payable_entity_type == 'branch_ticket_order',
            )
        )
        return int(value or 0)

    @staticmethod
    def _branch(branch) -> AdminCustomerBranchResponse | None:
        if branch is None:
            return None
        return AdminCustomerBranchResponse(
            id=branch.id,
            name=branch.name,
            shortLabel=branch.short_label,
        )
