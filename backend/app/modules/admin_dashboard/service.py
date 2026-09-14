from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, time, timedelta

from ...core.time.business_time import BUSINESS_TIMEZONE
from .repository import AdminDashboardRepository
from .schemas import OwnerDashboardPeriod, OwnerDashboardResponse


class AdminDashboardService:
    def __init__(
        self,
        *,
        repository: AdminDashboardRepository,
        now_provider: Callable[[], datetime] | None = None,
    ) -> None:
        self.repository = repository
        self.now_provider = now_provider or (lambda: datetime.now(UTC))

    def get_owner_dashboard(self, period: OwnerDashboardPeriod) -> OwnerDashboardResponse:
        now = self._normalize_now(self.now_provider())
        local_today = now.astimezone(BUSINESS_TIMEZONE).date()
        days_back = {
            OwnerDashboardPeriod.TODAY: 0,
            OwnerDashboardPeriod.SEVEN_DAYS: 6,
            OwnerDashboardPeriod.THIRTY_DAYS: 29,
        }[period]
        period_start = datetime.combine(
            local_today - timedelta(days=days_back),
            time.min,
            tzinfo=BUSINESS_TIMEZONE,
        )
        metrics = self.repository.period_metrics(
            # Persisted timestamps are UTC-aware on PostgreSQL (and become
            # naive UTC values on SQLite tests), so keep DB boundaries in UTC.
            period_start=period_start.astimezone(UTC),
            period_end=now,
        )
        return OwnerDashboardResponse(
            period=period,
            periodStart=period_start,
            periodEnd=now,
            timezone=BUSINESS_TIMEZONE.key,
            ticketCashCollectedTenge=metrics.ticket_cash_collected_tenge,
            paidTicketPurchases=metrics.paid_ticket_purchases,
            ticketsSold=metrics.tickets_sold,
            visits=metrics.visits,
            newFamilies=metrics.new_families,
            returningFamilies=metrics.returning_families,
            bonusesIssued=metrics.bonuses_issued,
            bonusesRedeemed=metrics.bonuses_redeemed,
            outstandingBonusBalance=metrics.outstanding_bonus_balance,
        )

    @staticmethod
    def _normalize_now(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)
