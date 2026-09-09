from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ...core.exceptions.http import NotFoundException
from ...db.models.birthday_request import BirthdayRequest
from ...db.models.push_campaign import PushCampaign
from ...db.models.push_campaign_delivery import PushCampaignDelivery
from ...db.models.push_campaign_open import PushCampaignOpen
from ...db.models.visit import Visit

ATTRIBUTION_WINDOW_DAYS = 7
ATTRIBUTION_WINDOW = timedelta(days=ATTRIBUTION_WINDOW_DAYS)


@dataclass(frozen=True)
class PushCampaignAttribution:
    campaign_id: str
    targeted_users: int
    sent_users: int
    opened_users: int
    open_rate: float | None
    attributed_visit_users: int
    attributed_visits: int
    attributed_birthday_lead_users: int
    attributed_birthday_leads: int
    attribution_window_days: int = ATTRIBUTION_WINDOW_DAYS
    attribution_model: str = 'last_touch'


def _utc(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=UTC)


class PushCampaignAttributionService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def record_open(self, campaign_id: str, mobile_user_id: str, *, opened_at: datetime | None = None) -> None:
        """Record one authenticated open, only for a snapshotted recipient."""
        campaign_exists = self.session.scalar(
            select(PushCampaign.id).where(PushCampaign.id == campaign_id)
        )
        if campaign_exists is None:
            raise NotFoundException(code='campaign_not_found', message='Кампания не найдена.')

        delivery_exists = self.session.scalar(
            select(PushCampaignDelivery.id).where(
                PushCampaignDelivery.campaign_id == campaign_id,
                PushCampaignDelivery.mobile_user_id == mobile_user_id,
                PushCampaignDelivery.status == 'sent',
            ).limit(1)
        )
        if delivery_exists is None:
            # Do not reveal campaign membership for another user. A recipient
            # whose delivery is still being finalized will retry after auth and
            # provider state are available.
            raise NotFoundException(code='campaign_open_not_allowed', message='Открытие кампании недоступно.')

        existing = self.session.scalar(
            select(PushCampaignOpen).where(
                PushCampaignOpen.campaign_id == campaign_id,
                PushCampaignOpen.mobile_user_id == mobile_user_id,
            )
        )
        if existing is not None:
            return

        self.session.add(
            PushCampaignOpen(
                campaign_id=campaign_id,
                mobile_user_id=mobile_user_id,
                opened_at=opened_at or datetime.now(UTC),
            )
        )
        try:
            self.session.commit()
        except IntegrityError:
            # Two taps can race on PostgreSQL's unique key. The first open is
            # durable; the retry is intentionally idempotent.
            self.session.rollback()

    def report(self, campaign_id: str) -> PushCampaignAttribution:
        campaign = self.session.scalar(select(PushCampaign).where(PushCampaign.id == campaign_id))
        if campaign is None:
            raise NotFoundException(code='campaign_not_found', message='Кампания не найдена.')

        sent_user_ids = set(self.session.scalars(
            select(PushCampaignDelivery.mobile_user_id).where(
                PushCampaignDelivery.campaign_id == campaign_id,
                PushCampaignDelivery.status == 'sent',
            ).distinct()
        ).all())
        campaign_opens = list(self.session.scalars(
            select(PushCampaignOpen).where(PushCampaignOpen.campaign_id == campaign_id)
        ).all())
        opened_user_ids = {item.mobile_user_id for item in campaign_opens}
        all_user_ids = sent_user_ids | opened_user_ids

        all_opens = []
        visits: list[Visit] = []
        leads: list[BirthdayRequest] = []
        if all_user_ids:
            all_opens = list(self.session.scalars(
                select(PushCampaignOpen).where(PushCampaignOpen.mobile_user_id.in_(all_user_ids))
            ).all())
            visits = list(self.session.scalars(
                select(Visit).where(Visit.mobile_user_id.in_(all_user_ids))
            ).all())
            leads = list(self.session.scalars(
                select(BirthdayRequest).where(
                    BirthdayRequest.mobile_user_id.in_(all_user_ids),
                    BirthdayRequest.mobile_user_id.is_not(None),
                )
            ).all())

        opens_by_user: dict[str, list[PushCampaignOpen]] = {}
        for item in all_opens:
            opens_by_user.setdefault(item.mobile_user_id, []).append(item)
        for items in opens_by_user.values():
            items.sort(key=lambda item: (_utc(item.opened_at), item.id))

        attributed_visits = [
            visit for visit in visits
            if visit.started_at is not None
            and self._last_touch_campaign(opens_by_user.get(visit.mobile_user_id, []), visit.started_at) == campaign_id
        ]
        attributed_leads = [
            lead for lead in leads
            if lead.created_at is not None
            and self._last_touch_campaign(opens_by_user.get(lead.mobile_user_id or '', []), lead.created_at) == campaign_id
        ]

        return PushCampaignAttribution(
            campaign_id=campaign_id,
            targeted_users=campaign.targeted_users,
            sent_users=len(sent_user_ids),
            opened_users=len(opened_user_ids),
            open_rate=(len(opened_user_ids) / len(sent_user_ids)) if sent_user_ids else None,
            attributed_visit_users=len({visit.mobile_user_id for visit in attributed_visits}),
            attributed_visits=len(attributed_visits),
            attributed_birthday_lead_users=len({lead.mobile_user_id for lead in attributed_leads if lead.mobile_user_id}),
            attributed_birthday_leads=len(attributed_leads),
        )

    @staticmethod
    def _last_touch_campaign(opens: list[PushCampaignOpen], outcome_at: datetime) -> str | None:
        outcome_at = _utc(outcome_at)
        eligible = [
            item for item in opens
            if _utc(item.opened_at) <= outcome_at < _utc(item.opened_at) + ATTRIBUTION_WINDOW
        ]
        if not eligible:
            return None
        return max(eligible, key=lambda item: (_utc(item.opened_at), item.id)).campaign_id
