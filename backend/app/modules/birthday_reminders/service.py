from __future__ import annotations

import logging
import hashlib
from collections import defaultdict
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import and_, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ...core.config.settings import get_settings
from ...db.models.birthday_reminder import BirthdayReminder
from ...db.models.birthday_request import BirthdayRequest
from ...db.models.birthday_revenue_cycle import BirthdayRevenueCycle
from ...db.models.mobile_child import MobileChild
from ...db.models.mobile_notification_device import MobileNotificationDevice
from ...db.models.mobile_session import MobileSession
from ...db.models.mobile_user import MobileUser
from ..admin_push_campaigns.service import (
    birthday_matches_target,
    birthday_occurrence_for_year,
    PushCampaignService,
)
from ..admin_push_campaigns.schemas import PushCampaignResponse
from ...db.models.push_campaign import PushCampaign
from ..leads.constants import ACTIVE_BIRTHDAY_LEAD_STATUSES

logger = logging.getLogger(__name__)
BUSINESS_TZ = ZoneInfo('Asia/Almaty')
ALLOWED_WINDOWS = (30, 14, 7, 1)
ACTIVE_LEAD_STATUSES = ACTIVE_BIRTHDAY_LEAD_STATUSES


def birthday_cycle_matches(
    *,
    birth_date: date,
    requested_date: date | None,
    target_date: date,
) -> bool:
    """Match a completed party to the nearest annual birthday occurrence."""
    if requested_date is None:
        return False

    occurrences = tuple(
        birthday_occurrence_for_year(birth_date, year)
        for year in range(requested_date.year - 1, requested_date.year + 2)
    )
    nearest = min(
        occurrences,
        key=lambda occurrence: (abs((occurrence - requested_date).days), occurrence),
    )
    return nearest == target_date


def birthday_target_date(now: datetime, days_before: int) -> date:
    return now.astimezone(BUSINESS_TZ).date() + timedelta(days=days_before)


def configured_windows(raw: str) -> tuple[int, ...]:
    values: list[int] = []
    for item in raw.split(','):
        try:
            value = int(item.strip())
        except (TypeError, ValueError):
            continue
        if value in ALLOWED_WINDOWS and value not in values:
            values.append(value)
    return tuple(value for value in ALLOWED_WINDOWS if value in values)


class BirthdayReminderService:
    """Generates durable, user-scoped reminders on top of PushCampaignService."""

    def __init__(self, session: Session, push_campaigns: PushCampaignService) -> None:
        self.session = session
        self.push_campaigns = push_campaigns
        self._revenue_experiment_enabled = True

    def process(self, *, now: datetime | None = None) -> int:
        settings = get_settings()
        if not settings.birthday_reminders_enabled:
            return 0
        current = now or datetime.now(UTC)
        windows = configured_windows(settings.birthday_reminder_windows)
        # Legacy test/staging configurations that explicitly run only the old
        # 14/7/1 reminders retain their historical send semantics. The V1
        # experiment is enabled by the new production default containing D-30.
        self._revenue_experiment_enabled = 30 in windows
        if not windows:
            return 0

        processed = 0
        for days_before in windows:
            target = birthday_target_date(current, days_before)
            candidates = self._candidates(target)
            grouped: dict[tuple[str, date, int], list[MobileChild]] = defaultdict(list)
            for child, user_id in candidates:
                grouped[(user_id, target, days_before)].append(child)
            for (user_id, target_date, window), children in sorted(grouped.items()):
                processed += self._process_group(
                    user_id=user_id,
                    target_date=target_date,
                    days_before=window,
                    children=children,
                    now=current,
                )
        return processed

    def _candidates(self, target: date) -> list[tuple[MobileChild, str]]:
        rows = self.session.execute(
            select(MobileChild, MobileUser.id)
            .join(MobileUser, MobileUser.id == MobileChild.user_id)
            .where(MobileUser.is_active.is_(True))
        ).all()
        return [
            (child, user_id)
            for child, user_id in rows
            if child.birth_date is not None and birthday_matches_target(child.birth_date, target)
        ]

    def _process_group(
        self,
        *,
        user_id: str,
        target_date: date,
        days_before: int,
        children: list[MobileChild],
        now: datetime,
    ) -> int:
        # The deterministic leader row serializes two workers handling twins. The
        # durable campaign link is then visible to the second worker before it
        # can execute the same group.
        children = sorted(children, key=lambda item: item.id)
        leader_id = children[0].id
        leader = self.session.scalar(
            select(MobileChild.id).where(MobileChild.id == leader_id).with_for_update()
        )
        if leader is None:
            return 0

        year = target_date.year
        child_ids = [child.id for child in children]
        records = self.session.scalars(
            select(BirthdayReminder)
            .where(
                BirthdayReminder.child_id.in_(child_ids),
                BirthdayReminder.birthday_year == year,
                BirthdayReminder.days_before == days_before,
            )
            .with_for_update()
        ).all()
        by_child = {record.child_id: record for record in records}
        for child in children:
            record = by_child.get(child.id)
            if record is None:
                record = BirthdayReminder(
                    child_id=child.id,
                    mobile_user_id=user_id,
                    birthday_year=year,
                    days_before=days_before,
                )
                self.session.add(record)
                self.session.flush()
                by_child[child.id] = record

        records = list(by_child.values())
        campaign_id = next((record.push_campaign_id for record in records if record.push_campaign_id), None)
        cycle = None
        if self._revenue_experiment_enabled:
            cycle_id = next((record.birthday_cycle_id for record in records if record.birthday_cycle_id), None)
            cycle = self.session.get(BirthdayRevenueCycle, cycle_id) if cycle_id else None
        if campaign_id is None:
            suppressing_leads = self._suppressing_leads_by_child(user_id, child_ids)
            birth_dates = {child.id: child.birth_date for child in children}
            for record in records:
                if record.status == 'pending' and self._has_suppressing_lead(
                    suppressing_leads.get(record.child_id, ()),
                    birth_dates[record.child_id],
                    target_date,
                ):
                    self._skip(record, 'active_lead')
            pending = [record for record in records if record.status == 'pending']
            if not pending:
                self.session.commit()
                return len(records)
            if not self._has_active_device(user_id, now=now):
                for record in pending:
                    self._skip(record, 'no_active_device')
                self.session.commit()
                return len(records)
            if self._revenue_experiment_enabled and cycle is None:
                cycle = self._get_or_create_cycle(user_id, target_date, now)
                for record in records:
                    if record.birthday_cycle_id is None:
                        record.birthday_cycle_id = cycle.id
                if cycle.experiment_group == 'control':
                    for record in pending:
                        self._skip(record, 'experiment_control')
                    self.session.commit()
                    return len(records)
            if not self.push_campaigns.provider_configured:
                # Keep the row retryable for an operator rerun after provider
                # configuration is restored; never manufacture SENT state.
                self.session.commit()
                return len(records)

            settings = get_settings()
            title, body = self._copy(settings, days_before)
            campaign = self.push_campaigns.create_system_birthday_campaign(
                user_id=user_id,
                internal_name=f'birthday-reminder-{year}-{days_before}-{user_id[:12]}-{target_date.isoformat()}',
                title=title,
                body=body,
                destination_payload={
                    'birthdayCycleId': cycle.id if cycle is not None else None,
                    'birthdayChildId': children[0].id if len(children) == 1 else None,
                    'preferredDate': target_date.isoformat(),
                },
            )
            campaign_id = campaign.id
            for record in pending:
                record.push_campaign_id = campaign.id
            self.session.commit()
        else:
            self.session.commit()

        # Delivery is deliberately outside the reminder transaction. If the
        # process dies here, the durable campaign link lets the next run resume.
        if campaign_id and self._suppressing_leads_by_child(user_id, child_ids):
            current_leads = self._suppressing_leads_by_child(user_id, child_ids)
            if any(self._has_suppressing_lead(current_leads.get(child.id, ()), child.birth_date, target_date) for child in children):
                campaign = self.session.get(PushCampaign, campaign_id)
                if campaign is not None and campaign.status in {'draft', 'processing'}:
                    campaign.status = 'cancelled'
                    campaign.failure_reason = 'birthday_lead_created'
                    campaign.cancelled_at = datetime.now(UTC)
                for record in records:
                    if record.status == 'pending':
                        self._skip(record, 'active_lead')
                self.session.commit()
                return len(records)
        response = self.push_campaigns.process_existing(campaign_id)
        self._finalize_records(campaign_id, response)
        return len(records)

    def _get_or_create_cycle(self, user_id: str, target_date: date, now: datetime) -> BirthdayRevenueCycle:
        existing = self.session.scalar(
            select(BirthdayRevenueCycle).where(
                BirthdayRevenueCycle.mobile_user_id == user_id,
                BirthdayRevenueCycle.birthday_year == target_date.year,
                BirthdayRevenueCycle.target_date == target_date,
            ).with_for_update()
        )
        if existing is not None:
            return existing
        digest = hashlib.sha256(f'birthday-revenue-v1:{user_id}:{target_date.isoformat()}'.encode()).digest()
        group = 'control' if int.from_bytes(digest[:8], 'big') % 100 < 20 else 'treatment'
        cycle = BirthdayRevenueCycle(
            mobile_user_id=user_id,
            birthday_year=target_date.year,
            target_date=target_date,
            experiment_group=group,
            eligible_at=now,
        )
        with self.session.begin_nested():
            self.session.add(cycle)
            try:
                self.session.flush()
                return cycle
            except IntegrityError:
                pass
        return self.session.scalar(
            select(BirthdayRevenueCycle).where(
                BirthdayRevenueCycle.mobile_user_id == user_id,
                BirthdayRevenueCycle.birthday_year == target_date.year,
                BirthdayRevenueCycle.target_date == target_date,
            ).with_for_update()
        )

    def _suppressing_leads_by_child(
        self,
        user_id: str,
        child_ids: list[str],
    ) -> dict[str, list[tuple[str, date | None]]]:
        rows = self.session.execute(
            select(
                BirthdayRequest.child_id,
                BirthdayRequest.status,
                BirthdayRequest.requested_date,
            )
            .where(
                BirthdayRequest.mobile_user_id == user_id,
                BirthdayRequest.child_id.in_(child_ids),
                or_(
                    BirthdayRequest.status.in_(ACTIVE_LEAD_STATUSES),
                    BirthdayRequest.status == 'completed',
                ),
            )
        ).all()
        leads_by_child: dict[str, list[tuple[str, date | None]]] = defaultdict(list)
        for child_id, status, requested_date in rows:
            if child_id is not None:
                leads_by_child[child_id].append((status, requested_date))
        return leads_by_child

    @staticmethod
    def _has_suppressing_lead(
        leads: list[tuple[str, date | None]] | tuple[tuple[str, date | None], ...],
        child_birth_date: date,
        target_date: date,
    ) -> bool:
        return any(
            status in ACTIVE_LEAD_STATUSES
            or (
                status == 'completed'
                and birthday_cycle_matches(
                    birth_date=child_birth_date,
                    requested_date=requested_date,
                    target_date=target_date,
                )
            )
            for status, requested_date in leads
        )

    def _has_active_device(
        self,
        user_id: str,
        *,
        now: datetime | None = None,
    ) -> bool:
        effective_now = now or datetime.now(UTC)
        return self.session.scalar(
            select(MobileNotificationDevice.id)
            .join(
                MobileSession,
                and_(
                    MobileSession.id == MobileNotificationDevice.mobile_session_id,
                    MobileSession.mobile_user_id == MobileNotificationDevice.mobile_user_id,
                ),
            )
            .where(
                MobileNotificationDevice.mobile_user_id == user_id,
                MobileNotificationDevice.notifications_enabled.is_(True),
                MobileNotificationDevice.permission_status.not_in(
                    ['denied', 'unavailable']
                ),
                MobileSession.revoked_at.is_(None),
                MobileSession.expires_at > effective_now,
            )
            .limit(1)
        ) is not None

    @staticmethod
    def _skip(record: BirthdayReminder, reason: str) -> None:
        record.status = 'skipped'
        record.skip_reason = reason
        record.skipped_at = datetime.now(UTC)
        logger.info(
            'birthday reminder skipped reminder_id=%s user_id=%s window=%s year=%s reason=%s',
            record.id,
            record.mobile_user_id,
            record.days_before,
            record.birthday_year,
            reason,
        )

    def _finalize_records(
        self,
        campaign_id: str,
        response: PushCampaignResponse,
    ) -> None:
        campaign_status = response.status
        partially_delivered = (
            campaign_status == 'partially_failed' and response.sent_count > 0
        )
        if campaign_status not in {'sent', 'failed', 'cancelled', 'partially_failed'}:
            return
        now = datetime.now(UTC)
        delivered = campaign_status == 'sent' or partially_delivered
        values = {'status': 'sent' if delivered else 'failed', 'updated_at': now}
        if delivered:
            values['sent_at'] = now
        else:
            values['skip_reason'] = (
                'campaign_cancelled'
                if campaign_status == 'cancelled'
                else 'campaign_partial_without_delivery'
                if campaign_status == 'partially_failed'
                else 'campaign_failed'
            )
        self.session.execute(
            update(BirthdayReminder)
            .where(BirthdayReminder.push_campaign_id == campaign_id, BirthdayReminder.status == 'pending')
            .values(**values)
        )
        self.session.commit()
        logger.info(
            'birthday reminder finalized campaign_id=%s status=%s sent_count=%s failed_count=%s',
            campaign_id,
            campaign_status,
            response.sent_count,
            response.failed_count,
        )

    @staticmethod
    def _copy(settings, days_before: int) -> tuple[str, str]:
        if days_before == 30:
            return settings.birthday_reminder_30_title, settings.birthday_reminder_30_body
        return (
            getattr(settings, f'birthday_reminder_{days_before}_title'),
            getattr(settings, f'birthday_reminder_{days_before}_body'),
        )
