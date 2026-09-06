from __future__ import annotations

import logging
from collections import defaultdict
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from ...core.config.settings import get_settings
from ...db.models.birthday_reminder import BirthdayReminder
from ...db.models.birthday_request import BirthdayRequest
from ...db.models.mobile_child import MobileChild
from ...db.models.mobile_notification_device import MobileNotificationDevice
from ...db.models.mobile_user import MobileUser
from ..admin_push_campaigns.service import birthday_matches_target, PushCampaignService

logger = logging.getLogger(__name__)
BUSINESS_TZ = ZoneInfo('Asia/Almaty')
ALLOWED_WINDOWS = (14, 7, 1)
ACTIVE_LEAD_STATUSES = {'new', 'contacted', 'in_progress', 'confirmed'}


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

    def process(self, *, now: datetime | None = None) -> int:
        settings = get_settings()
        if not settings.birthday_reminders_enabled:
            return 0
        current = now or datetime.now(UTC)
        windows = configured_windows(settings.birthday_reminder_windows)
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
        if campaign_id is None:
            for record in records:
                if record.status == 'pending' and self._has_active_lead(record.child_id, user_id):
                    self._skip(record, 'active_lead')
            pending = [record for record in records if record.status == 'pending']
            if not pending:
                self.session.commit()
                return len(records)
            if not self._has_active_device(user_id):
                for record in pending:
                    self._skip(record, 'no_active_device')
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
            )
            campaign_id = campaign.id
            for record in pending:
                record.push_campaign_id = campaign.id
            self.session.commit()
        else:
            self.session.commit()

        # Delivery is deliberately outside the reminder transaction. If the
        # process dies here, the durable campaign link lets the next run resume.
        response = self.push_campaigns.process_existing(campaign_id)
        self._finalize_records(campaign_id, response.status)
        return len(records)

    def _has_active_lead(self, child_id: str | None, user_id: str) -> bool:
        if child_id is None:
            return False
        return self.session.scalar(
            select(BirthdayRequest.id)
            .where(
                BirthdayRequest.mobile_user_id == user_id,
                BirthdayRequest.child_id == child_id,
                BirthdayRequest.status.in_(ACTIVE_LEAD_STATUSES),
            )
            .limit(1)
        ) is not None

    def _has_active_device(self, user_id: str) -> bool:
        return self.session.scalar(
            select(MobileNotificationDevice.id)
            .where(
                MobileNotificationDevice.mobile_user_id == user_id,
                MobileNotificationDevice.notifications_enabled.is_(True),
                MobileNotificationDevice.permission_status.not_in(['denied', 'unavailable']),
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

    def _finalize_records(self, campaign_id: str, campaign_status: str) -> None:
        if campaign_status not in {'sent', 'failed', 'cancelled'}:
            return
        now = datetime.now(UTC)
        values = {'status': 'sent' if campaign_status == 'sent' else 'failed', 'updated_at': now}
        if campaign_status == 'sent':
            values['sent_at'] = now
        else:
            values['skip_reason'] = 'campaign_failed' if campaign_status == 'failed' else 'campaign_cancelled'
        self.session.execute(
            update(BirthdayReminder)
            .where(BirthdayReminder.push_campaign_id == campaign_id, BirthdayReminder.status == 'pending')
            .values(**values)
        )
        self.session.commit()
        logger.info(
            'birthday reminder finalized campaign_id=%s status=%s',
            campaign_id,
            campaign_status,
        )

    @staticmethod
    def _copy(settings, days_before: int) -> tuple[str, str]:
        return (
            getattr(settings, f'birthday_reminder_{days_before}_title'),
            getattr(settings, f'birthday_reminder_{days_before}_body'),
        )
