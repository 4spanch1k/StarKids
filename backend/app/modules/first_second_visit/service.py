from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import and_, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ...db.models.lifecycle_journey_execution import LifecycleJourneyExecution
from ...db.models.mobile_notification_device import MobileNotificationDevice
from ...db.models.mobile_session import MobileSession
from ...db.models.mobile_user import MobileUser
from ...db.models.push_campaign import PushCampaign
from ...db.models.push_campaign_open import PushCampaignOpen
from ...db.models.visit import Visit
from ..visit_segmentation.service import business_date
from ..admin_push_campaigns.service import PushCampaignService

JOURNEY_KEY = 'first_to_second_visit_v1'
MIN_DAYS = 4
WINDOW_DAYS = 30
BUSINESS_TZ = ZoneInfo('Asia/Almaty')
# ``business_date`` is the project's Asia/Almaty calendar-date helper. The
# journey's day windows are calendar days, not Monday-to-Friday workdays.


@dataclass(frozen=True)
class FirstSecondVisitReport:
    journey_key: str
    eligible_families: int
    control_size: int
    treatment_size: int
    treatment_delivered: int
    treatment_opened: int
    control_conversions: int
    treatment_conversions: int
    control_second_visit_rate: float | None
    treatment_second_visit_rate: float | None
    absolute_uplift_percentage_points: float | None


class FirstSecondVisitService:
    """Small, durable first-visit reactivation experiment.

    Visit rows are the source of truth. The execution table only stores the
    immutable assignment and auditable campaign/conversion pointers.
    """

    def __init__(self, session: Session, push_campaigns: PushCampaignService) -> None:
        self.session = session
        self.push_campaigns = push_campaigns

    def process(self, *, now: datetime | None = None) -> int:
        effective_now = self._utc(now)
        self._record_conversions(effective_now)
        self._sync_campaign_results()
        processed = 0
        for user_id, first_visit_id, first_visit_at in self._eligible_candidates(effective_now):
            if self._ensure_still_eligible(user_id, first_visit_id, first_visit_at, effective_now):
                self._ensure_execution(user_id, first_visit_id, first_visit_at, effective_now)
                processed += 1
        self.session.commit()
        return processed

    def report(self) -> FirstSecondVisitReport:
        executions = self.session.scalars(
            select(LifecycleJourneyExecution).where(LifecycleJourneyExecution.journey_key == JOURNEY_KEY)
        ).all()
        control = [e for e in executions if e.experiment_group == 'control']
        treatment = [e for e in executions if e.experiment_group == 'treatment']
        treatment_campaign_ids = [e.push_campaign_id for e in treatment if e.push_campaign_id]
        delivered = 0
        opened = 0
        if treatment_campaign_ids:
            delivered = self.session.scalar(
                select(func.count()).select_from(LifecycleJourneyExecution).join(
                    PushCampaign, PushCampaign.id == LifecycleJourneyExecution.push_campaign_id
                ).where(
                    LifecycleJourneyExecution.journey_key == JOURNEY_KEY,
                    LifecycleJourneyExecution.experiment_group == 'treatment',
                    PushCampaign.sent_count > 0,
                )
            ) or 0
            opened = self.session.scalar(
                select(func.count(func.distinct(PushCampaignOpen.mobile_user_id))).select_from(PushCampaignOpen).join(
                    LifecycleJourneyExecution, LifecycleJourneyExecution.push_campaign_id == PushCampaignOpen.campaign_id
                ).where(LifecycleJourneyExecution.journey_key == JOURNEY_KEY)
            ) or 0
        control_conversions = sum(e.converted_at is not None for e in control)
        treatment_conversions = sum(e.converted_at is not None for e in treatment)
        control_rate = self._rate(control_conversions, len(control))
        treatment_rate = self._rate(treatment_conversions, len(treatment))
        uplift = (treatment_rate - control_rate) * 100 if control_rate is not None and treatment_rate is not None else None
        return FirstSecondVisitReport(
            journey_key=JOURNEY_KEY,
            eligible_families=len(executions),
            control_size=len(control),
            treatment_size=len(treatment),
            treatment_delivered=int(delivered),
            treatment_opened=int(opened),
            control_conversions=control_conversions,
            treatment_conversions=treatment_conversions,
            control_second_visit_rate=control_rate,
            treatment_second_visit_rate=treatment_rate,
            absolute_uplift_percentage_points=uplift,
        )

    def _eligible_candidates(self, now: datetime) -> list[tuple[str, str, datetime]]:
        visit_counts = (
            select(
                Visit.mobile_user_id.label('user_id'),
                func.min(Visit.started_at).label('first_visit_at'),
                func.count(Visit.id).label('visit_count'),
            )
            .where(Visit.status.in_(['active', 'completed']))
            .group_by(Visit.mobile_user_id)
            .having(func.count(Visit.id) == 1)
            .subquery()
        )
        rows = self.session.execute(
            select(visit_counts.c.user_id, visit_counts.c.first_visit_at)
            .join(MobileUser, MobileUser.id == visit_counts.c.user_id)
            .join(
                MobileNotificationDevice,
                MobileNotificationDevice.mobile_user_id == MobileUser.id,
            )
            .join(
                MobileSession,
                and_(
                    MobileSession.id == MobileNotificationDevice.mobile_session_id,
                    MobileSession.mobile_user_id == MobileNotificationDevice.mobile_user_id,
                ),
            )
            .where(
                MobileUser.is_active.is_(True),
                MobileUser.onboarding_completed_at.is_not(None),
                MobileNotificationDevice.notifications_enabled.is_(True),
                MobileNotificationDevice.permission_status.not_in(['denied', 'unavailable']),
                MobileSession.revoked_at.is_(None),
                MobileSession.expires_at > now,
            )
            .distinct()
        ).all()
        result: list[tuple[str, str, datetime]] = []
        for row in rows:
            visit = self.session.scalar(
                select(Visit).where(
                    Visit.mobile_user_id == row.user_id,
                    Visit.status.in_(['active', 'completed']),
                ).order_by(Visit.started_at.asc(), Visit.id.asc()).limit(1)
            )
            if visit is not None:
                age_days = (business_date(now) - business_date(visit.started_at)).days
                if MIN_DAYS <= age_days < WINDOW_DAYS:
                    result.append((str(row.user_id), visit.id, row.first_visit_at))
        return result

    def _ensure_still_eligible(self, user_id: str, first_visit_id: str, first_visit_at: datetime, now: datetime) -> bool:
        visits = self.session.scalars(
            select(Visit).where(
                Visit.mobile_user_id == user_id,
                Visit.status.in_(['active', 'completed']),
            ).order_by(Visit.started_at.asc(), Visit.id.asc())
        ).all()
        if len(visits) != 1 or visits[0].id != first_visit_id:
            return False
        age_days = (business_date(now) - business_date(first_visit_at)).days
        return MIN_DAYS <= age_days < WINDOW_DAYS

    def _ensure_execution(self, user_id: str, first_visit_id: str, first_visit_at: datetime, now: datetime) -> LifecycleJourneyExecution:
        execution = self.session.scalar(
            select(LifecycleJourneyExecution).where(
                LifecycleJourneyExecution.journey_key == JOURNEY_KEY,
                LifecycleJourneyExecution.mobile_user_id == user_id,
            ).with_for_update()
        )
        if execution is not None:
            return execution
        group = self._assign_group(user_id)
        execution = LifecycleJourneyExecution(
            journey_key=JOURNEY_KEY,
            mobile_user_id=user_id,
            experiment_group=group,
            eligible_at=now,
            first_visit_id=first_visit_id,
            first_visit_at=first_visit_at,
        )
        try:
            # The execution uniqueness constraint is expected to race when two
            # workers discover the same family. Keep that conflict inside a
            # SAVEPOINT so work already done in this outer batch transaction
            # (conversions and campaign sync) remains commit-able.
            with self.session.begin_nested():
                self.session.add(execution)
                self.session.flush()
        except IntegrityError:
            existing = self.session.scalar(
                select(LifecycleJourneyExecution).where(
                    LifecycleJourneyExecution.journey_key == JOURNEY_KEY,
                    LifecycleJourneyExecution.mobile_user_id == user_id,
                )
            )
            if existing is None:
                raise
            return existing
        if group == 'treatment':
            campaign = self.push_campaigns.create_system_first_to_second_visit_campaign(user_id=user_id)
            execution.push_campaign_id = campaign.id
            self.session.flush()
        return execution

    def _record_conversions(self, now: datetime) -> None:
        executions = self.session.scalars(
            select(LifecycleJourneyExecution).where(
                LifecycleJourneyExecution.journey_key == JOURNEY_KEY,
                LifecycleJourneyExecution.converted_at.is_(None),
            ).with_for_update()
        ).all()
        for execution in executions:
            conversion = self.session.scalar(
                select(Visit).where(
                    Visit.mobile_user_id == execution.mobile_user_id,
                    Visit.status.in_(['active', 'completed']),
                    Visit.started_at > execution.first_visit_at,
                    Visit.started_at <= now,
                ).order_by(Visit.started_at.asc(), Visit.id.asc()).limit(1)
            )
            if conversion is not None:
                conversion_age = (business_date(conversion.started_at) - business_date(execution.first_visit_at)).days
                if 0 <= conversion_age <= WINDOW_DAYS:
                    execution.converted_at = conversion.started_at
                    execution.conversion_visit_id = conversion.id

    def _sync_campaign_results(self) -> None:
        for execution in self.session.scalars(
            select(LifecycleJourneyExecution).where(
                LifecycleJourneyExecution.journey_key == JOURNEY_KEY,
                LifecycleJourneyExecution.push_campaign_id.is_not(None),
                LifecycleJourneyExecution.push_sent_at.is_(None),
            )
        ).all():
            campaign = self.session.get(PushCampaign, execution.push_campaign_id)
            if campaign is not None and campaign.sent_at is not None and campaign.sent_count > 0:
                execution.push_sent_at = campaign.sent_at

    @staticmethod
    def _assign_group(user_id: str) -> str:
        bucket = int(hashlib.sha256(f'{JOURNEY_KEY}:{user_id}'.encode()).hexdigest()[:8], 16) % 100
        return 'control' if bucket < 20 else 'treatment'

    @staticmethod
    def _utc(value: datetime | None) -> datetime:
        if value is None:
            return datetime.now(UTC)
        if value.tzinfo is None:
            return value.replace(tzinfo=BUSINESS_TZ).astimezone(UTC)
        return value.astimezone(UTC)

    @staticmethod
    def _rate(numerator: int, denominator: int) -> float | None:
        return numerator / denominator if denominator else None
