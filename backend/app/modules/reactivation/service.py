from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import UTC, datetime
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
from ..admin_push_campaigns.service import PushCampaignService
from ..visit_segmentation.service import business_date

JOURNEY_KEY = 'lapsed_reactivation_v1'
MIN_LAPSED_DAYS = 45
MAX_LAPSED_DAYS_EXCLUSIVE = 90
CONVERSION_WINDOW_DAYS = 30
BUSINESS_TZ = ZoneInfo('Asia/Almaty')
PHYSICAL_VISIT_STATUSES = ('active', 'completed')


@dataclass(frozen=True)
class ReactivationReport:
    journey_key: str
    eligible_families: int
    control_size: int
    treatment_size: int
    treatment_delivered: int
    treatment_opened: int
    control_conversions: int
    treatment_conversions: int
    control_reactivation_rate: float | None
    treatment_reactivation_rate: float | None
    absolute_uplift_percentage_points: float | None


class ReactivationService:
    """Durable 45–89 day reactivation experiment based on physical Visits."""

    def __init__(self, session: Session, push_campaigns: PushCampaignService) -> None:
        self.session = session
        self.push_campaigns = push_campaigns

    def process(self, *, now: datetime | None = None) -> int:
        effective_now = self._utc(now)
        self._record_conversions(effective_now)
        self._sync_campaign_results()
        processed = 0
        for user_id, anchor_visit_id, anchor_visit_at in self._eligible_candidates(effective_now):
            if self._ensure_still_eligible(user_id, anchor_visit_id, effective_now):
                self._ensure_execution(user_id, anchor_visit_id, anchor_visit_at, effective_now)
                processed += 1
        self.session.commit()
        return processed

    def report(self) -> ReactivationReport:
        executions = self.session.scalars(
            select(LifecycleJourneyExecution).where(
                LifecycleJourneyExecution.journey_key == JOURNEY_KEY
            )
        ).all()
        control = [item for item in executions if item.experiment_group == 'control']
        treatment = [item for item in executions if item.experiment_group == 'treatment']
        campaign_ids = [item.push_campaign_id for item in treatment if item.push_campaign_id]
        delivered = 0
        opened = 0
        if campaign_ids:
            delivered = int(
                self.session.scalar(
                    select(func.count()).select_from(LifecycleJourneyExecution).join(
                        PushCampaign,
                        PushCampaign.id == LifecycleJourneyExecution.push_campaign_id,
                    ).where(
                        LifecycleJourneyExecution.journey_key == JOURNEY_KEY,
                        LifecycleJourneyExecution.experiment_group == 'treatment',
                        PushCampaign.sent_count > 0,
                    )
                ) or 0
            )
            opened = int(
                self.session.scalar(
                    select(func.count(func.distinct(PushCampaignOpen.mobile_user_id))).select_from(
                        PushCampaignOpen
                    ).join(
                        LifecycleJourneyExecution,
                        LifecycleJourneyExecution.push_campaign_id == PushCampaignOpen.campaign_id,
                    ).where(LifecycleJourneyExecution.journey_key == JOURNEY_KEY)
                ) or 0
            )
        control_conversions = sum(item.converted_at is not None for item in control)
        treatment_conversions = sum(item.converted_at is not None for item in treatment)
        control_rate = self._rate(control_conversions, len(control))
        treatment_rate = self._rate(treatment_conversions, len(treatment))
        uplift = (
            (treatment_rate - control_rate) * 100
            if control_rate is not None and treatment_rate is not None
            else None
        )
        return ReactivationReport(
            journey_key=JOURNEY_KEY,
            eligible_families=len(executions),
            control_size=len(control),
            treatment_size=len(treatment),
            treatment_delivered=delivered,
            treatment_opened=opened,
            control_conversions=control_conversions,
            treatment_conversions=treatment_conversions,
            control_reactivation_rate=control_rate,
            treatment_reactivation_rate=treatment_rate,
            absolute_uplift_percentage_points=uplift,
        )

    def _eligible_candidates(self, now: datetime) -> list[tuple[str, str, datetime]]:
        valid_visits = (
            select(
                Visit.id,
                Visit.mobile_user_id,
                Visit.started_at,
            )
            .where(Visit.status.in_(PHYSICAL_VISIT_STATUSES))
            .subquery()
        )
        ranked_visits = (
            select(
                valid_visits.c.id,
                valid_visits.c.mobile_user_id,
                valid_visits.c.started_at,
                func.row_number().over(
                    partition_by=valid_visits.c.mobile_user_id,
                    order_by=(valid_visits.c.started_at.desc(), valid_visits.c.id.desc()),
                ).label('visit_rank'),
            )
            .subquery()
        )
        stats = (
            select(
                valid_visits.c.mobile_user_id.label('user_id'),
                func.count(valid_visits.c.id).label('visit_count'),
            )
            .group_by(valid_visits.c.mobile_user_id)
            .having(func.count(valid_visits.c.id) >= 2)
            .subquery()
        )
        rows = self.session.execute(
            select(
                stats.c.user_id,
                ranked_visits.c.id,
                ranked_visits.c.started_at,
            )
            .join(ranked_visits, and_(
                ranked_visits.c.mobile_user_id == stats.c.user_id,
                ranked_visits.c.visit_rank == 1,
            ))
            .join(MobileUser, MobileUser.id == stats.c.user_id)
            .join(MobileNotificationDevice, MobileNotificationDevice.mobile_user_id == MobileUser.id)
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
            age_days = (business_date(now) - business_date(row.started_at)).days
            if MIN_LAPSED_DAYS <= age_days < MAX_LAPSED_DAYS_EXCLUSIVE:
                result.append((str(row.user_id), str(row.id), row.started_at))
        return result

    def _ensure_still_eligible(self, user_id: str, anchor_visit_id: str, now: datetime) -> bool:
        user = self.session.scalar(
            select(MobileUser).where(
                MobileUser.id == user_id,
                MobileUser.is_active.is_(True),
                MobileUser.onboarding_completed_at.is_not(None),
            )
        )
        if user is None or not self._has_active_device(user_id, now):
            return False
        visits = self.session.scalars(
            select(Visit).where(
                Visit.mobile_user_id == user_id,
                Visit.status.in_(PHYSICAL_VISIT_STATUSES),
            ).order_by(Visit.started_at.desc(), Visit.id.desc())
        ).all()
        if len(visits) < 2 or visits[0].id != anchor_visit_id:
            return False
        age_days = (business_date(now) - business_date(visits[0].started_at)).days
        return MIN_LAPSED_DAYS <= age_days < MAX_LAPSED_DAYS_EXCLUSIVE

    def _ensure_execution(
        self,
        user_id: str,
        anchor_visit_id: str,
        anchor_visit_at: datetime,
        now: datetime,
    ) -> LifecycleJourneyExecution:
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
            anchor_visit_id=anchor_visit_id,
            anchor_visit_at=anchor_visit_at,
        )
        try:
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
            campaign = self.push_campaigns.create_system_reactivation_campaign(user_id=user_id)
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
                    Visit.status.in_(PHYSICAL_VISIT_STATUSES),
                    Visit.started_at >= execution.eligible_at,
                    Visit.started_at <= now,
                ).order_by(Visit.started_at.asc(), Visit.id.asc()).limit(1)
            )
            if conversion is None:
                continue
            age_days = (business_date(conversion.started_at) - business_date(execution.eligible_at)).days
            if 0 <= age_days <= CONVERSION_WINDOW_DAYS:
                execution.converted_at = conversion.started_at
                execution.conversion_visit_id = conversion.id

    def _sync_campaign_results(self) -> None:
        executions = self.session.scalars(
            select(LifecycleJourneyExecution).where(
                LifecycleJourneyExecution.journey_key == JOURNEY_KEY,
                LifecycleJourneyExecution.push_campaign_id.is_not(None),
                LifecycleJourneyExecution.push_sent_at.is_(None),
            )
        ).all()
        for execution in executions:
            campaign = self.session.get(PushCampaign, execution.push_campaign_id)
            if campaign is not None and campaign.sent_at is not None and campaign.sent_count > 0:
                execution.push_sent_at = campaign.sent_at

    def _has_active_device(self, user_id: str, now: datetime) -> bool:
        return self.session.scalar(
            select(MobileNotificationDevice.id).join(
                MobileSession,
                and_(
                    MobileSession.id == MobileNotificationDevice.mobile_session_id,
                    MobileSession.mobile_user_id == MobileNotificationDevice.mobile_user_id,
                ),
            ).where(
                MobileNotificationDevice.mobile_user_id == user_id,
                MobileNotificationDevice.notifications_enabled.is_(True),
                MobileNotificationDevice.permission_status.not_in(['denied', 'unavailable']),
                MobileSession.revoked_at.is_(None),
                MobileSession.expires_at > now,
            ).limit(1)
        ) is not None

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
