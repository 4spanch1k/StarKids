from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import and_, case, exists, func, select
from sqlalchemy.orm import aliased

from ...db.models.loyalty_account import LoyaltyAccount
from ...db.models.loyalty_transaction import LoyaltyTransaction
from ...db.models.mobile_payment import MobilePayment
from ...db.models.visit import Visit
from ...db.repositories.base import Repository
from ..mobile_payments.constants import PAYABLE_BRANCH_TICKET_ORDER, PAYMENT_STATUS_PAID


@dataclass(frozen=True)
class OwnerDashboardMetrics:
    ticket_cash_collected_tenge: int
    paid_ticket_purchases: int
    tickets_sold: int
    visits: int
    new_families: int
    returning_families: int
    bonuses_issued: int
    bonuses_redeemed: int
    outstanding_bonus_balance: int


class AdminDashboardRepository(Repository):
    """Read-side aggregates kept separate to avoid cartesian joins."""

    def period_metrics(self, *, period_start: datetime, period_end: datetime) -> OwnerDashboardMetrics:
        payment_count, cash_collected, tickets_sold = self.db.execute(
            select(
                func.count(MobilePayment.id),
                func.coalesce(func.sum(MobilePayment.cash_amount_tenge), 0),
                func.coalesce(func.sum(MobilePayment.quantity), 0),
            ).where(
                MobilePayment.status == PAYMENT_STATUS_PAID,
                MobilePayment.payable_entity_type == PAYABLE_BRANCH_TICKET_ORDER,
                MobilePayment.paid_at >= period_start,
                MobilePayment.paid_at <= period_end,
            )
        ).one()

        visits = self.db.scalar(
            select(func.count(Visit.id)).where(
                Visit.started_at >= period_start,
                Visit.started_at <= period_end,
            )
        )

        first_visits = (
            select(
                Visit.mobile_user_id.label('mobile_user_id'),
                func.min(Visit.started_at).label('first_visit_at'),
            )
            .group_by(Visit.mobile_user_id)
            .subquery()
        )
        new_families = self.db.scalar(
            select(func.count()).select_from(first_visits).where(
                first_visits.c.first_visit_at >= period_start,
                first_visits.c.first_visit_at <= period_end,
            )
        )

        current_visit = aliased(Visit)
        prior_visit = aliased(Visit)
        returning_families = self.db.scalar(
            select(func.count(func.distinct(current_visit.mobile_user_id))).where(
                current_visit.started_at >= period_start,
                current_visit.started_at <= period_end,
                exists(
                    select(prior_visit.id).where(
                        prior_visit.mobile_user_id == current_visit.mobile_user_id,
                        prior_visit.started_at < period_start,
                    )
                ),
            )
        )

        earn_condition = and_(
            LoyaltyTransaction.type == 'earn',
            LoyaltyTransaction.status == 'posted',
            LoyaltyTransaction.balance_delta > 0,
        )
        redeem_condition = and_(
            LoyaltyTransaction.type.in_(['spend', 'capture']),
            LoyaltyTransaction.status.in_(['posted', 'captured']),
            LoyaltyTransaction.balance_delta < 0,
        )
        bonuses_issued, bonuses_redeemed = self.db.execute(
            select(
                func.coalesce(
                    func.sum(case((earn_condition, LoyaltyTransaction.balance_delta), else_=0)),
                    0,
                ),
                func.coalesce(
                    func.sum(case((redeem_condition, -LoyaltyTransaction.balance_delta), else_=0)),
                    0,
                ),
            ).where(
                LoyaltyTransaction.created_at >= period_start,
                LoyaltyTransaction.created_at <= period_end,
            )
        ).one()

        outstanding = self.db.scalar(
            select(func.coalesce(func.sum(LoyaltyAccount.balance), 0))
        )

        return OwnerDashboardMetrics(
            ticket_cash_collected_tenge=int(cash_collected or 0),
            paid_ticket_purchases=int(payment_count or 0),
            tickets_sold=int(tickets_sold or 0),
            visits=int(visits or 0),
            new_families=int(new_families or 0),
            returning_families=int(returning_families or 0),
            bonuses_issued=int(bonuses_issued or 0),
            bonuses_redeemed=int(bonuses_redeemed or 0),
            outstanding_bonus_balance=int(outstanding or 0),
        )
