from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ...db.models.birthday_reminder import BirthdayReminder
from ...db.models.birthday_request import BirthdayRequest
from ...db.models.birthday_revenue_cycle import BirthdayRevenueCycle
from ...db.models.push_campaign import PushCampaign
from ...db.models.push_campaign_open import PushCampaignOpen


@dataclass(frozen=True)
class BirthdayRevenueReport:
    eligible_cycles: int
    control_cycles: int
    treatment_cycles: int
    windows: dict[str, dict[str, int]]
    control: dict[str, object]
    treatment: dict[str, object]
    lost_reasons: dict[str, int]
    absolute_uplift_percentage_points: float | None
    revenue_per_eligible_difference: float


class BirthdayRevenueReportService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def report(self) -> BirthdayRevenueReport:
        cycles = self.session.scalars(select(BirthdayRevenueCycle)).all()
        cycle_ids = {cycle.id for cycle in cycles}
        leads = self.session.scalars(select(BirthdayRequest).where(BirthdayRequest.birthday_cycle_id.in_(cycle_ids))).all() if cycle_ids else []
        leads_by_cycle: dict[str, list[BirthdayRequest]] = {}
        for lead in leads:
            leads_by_cycle.setdefault(lead.birthday_cycle_id, []).append(lead)
        grouped = {'control': [c for c in cycles if c.experiment_group == 'control'], 'treatment': [c for c in cycles if c.experiment_group == 'treatment']}
        summary = {key: self._summary(items, leads_by_cycle) for key, items in grouped.items()}
        lost: dict[str, int] = {}
        for lead in leads:
            if lead.status == 'lost' and lead.lost_reason:
                lost[lead.lost_reason] = lost.get(lead.lost_reason, 0) + 1
        control_rate = summary['control']['paid_rate']
        treatment_rate = summary['treatment']['paid_rate']
        uplift = (treatment_rate - control_rate) * 100 if control_rate is not None and treatment_rate is not None else None
        control_rev = summary['control']['revenue_per_eligible']
        treatment_rev = summary['treatment']['revenue_per_eligible']
        return BirthdayRevenueReport(
            eligible_cycles=len(cycles), control_cycles=len(grouped['control']), treatment_cycles=len(grouped['treatment']),
            windows=self._windows(cycles), control=summary['control'], treatment=summary['treatment'], lost_reasons=lost,
            absolute_uplift_percentage_points=uplift, revenue_per_eligible_difference=treatment_rev - control_rev,
        )

    def _summary(self, cycles, leads_by_cycle):
        rows = [lead for cycle in cycles for lead in leads_by_cycle.get(cycle.id, [])]
        paid = [lead for lead in rows if (lead.paid_amount_tenge or 0) > 0 and lead.paid_at is not None]
        revenue = sum(lead.paid_amount_tenge or 0 for lead in paid)
        size = len(cycles)
        # Rates measure family birthday-cycle outcomes, not raw lead rows. A
        # retry or a second lead for the same cycle must never make a cohort
        # rate exceed 100%.
        lead_cycle_ids = {
            cycle.id
            for cycle in cycles
            if leads_by_cycle.get(cycle.id)
        }
        paid_cycle_ids = {
            cycle.id
            for cycle in cycles
            if any(
                (lead.paid_amount_tenge or 0) > 0 and lead.paid_at is not None
                for lead in leads_by_cycle.get(cycle.id, [])
            )
        }
        return {
            'eligible': size, 'leads': len(rows), 'contacted': sum(lead.contacted_at is not None for lead in rows),
            'qualified': sum(lead.qualified_at is not None for lead in rows), 'booked': sum(lead.booked_at is not None for lead in rows),
            'paid': len(paid), 'completed': sum(lead.completed_at is not None for lead in rows), 'lost': sum(lead.status == 'lost' for lead in rows),
            'paid_revenue_tenge': revenue, 'paid_rate': len(paid_cycle_ids) / size if size else None, 'lead_rate': len(lead_cycle_ids) / size if size else None,
            'revenue_per_eligible': revenue / size if size else 0.0, 'average_paid_order_tenge': revenue / len(paid) if paid else None,
        }

    def _windows(self, cycles):
        cycle_ids = {cycle.id for cycle in cycles}
        result: dict[str, dict[str, int]] = {}
        for window in (30, 14, 7):
            reminders = self.session.scalars(select(BirthdayReminder).where(BirthdayReminder.birthday_cycle_id.in_(cycle_ids), BirthdayReminder.days_before == window, BirthdayReminder.push_campaign_id.is_not(None))).all() if cycle_ids else []
            campaign_ids = {row.push_campaign_id for row in reminders if row.push_campaign_id}
            campaigns = self.session.scalars(select(PushCampaign).where(PushCampaign.id.in_(campaign_ids))).all() if campaign_ids else []
            opened = self.session.scalar(select(func.count(func.distinct(PushCampaignOpen.mobile_user_id))).where(PushCampaignOpen.campaign_id.in_(campaign_ids))) if campaign_ids else 0
            result[str(window)] = {'campaigns': len(campaigns), 'delivered': sum(c.sent_count > 0 for c in campaigns), 'opened': int(opened or 0)}
        return result
