from __future__ import annotations

import calendar
import logging
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import and_, delete, extract, func, or_, select, update
from sqlalchemy.orm import Session

from ...core.config.settings import get_settings
from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.mobile_child import MobileChild
from ...db.models.mobile_notification_device import MobileNotificationDevice
from ...db.models.mobile_user import MobileUser
from ...db.models.push_campaign import PushCampaign
from ...db.models.push_campaign_delivery import PushCampaignDelivery
from ...services.push.delivery_port import PushDeliveryPort
from .schemas import (
    PushCampaignAudience,
    PushCampaignCreateRequest,
    PushCampaignPreviewResponse,
    PushCampaignResponse,
    PushCampaignUpdateRequest,
)

logger = logging.getLogger(__name__)
BUSINESS_TZ = ZoneInfo('Asia/Almaty')
MAX_ATTEMPTS = 3
STALE_SENDING_AFTER = timedelta(minutes=5)


def birthday_target_date(now: datetime, days_before_birthday: int) -> date:
    """Resolve campaign dates in the branch timezone, not server/UTC time."""
    return now.astimezone(BUSINESS_TZ).date() + timedelta(days=days_before_birthday)


def birthday_matches_target(birth_date: date, target: date) -> bool:
    """Match month/day birthdays with the explicit Feb-29 policy."""
    if birth_date.month != target.month:
        return False
    if target.month == 2 and target.day == 28 and birth_date.day in {28, 29}:
        return True
    return birth_date.day == target.day


def birthday_occurrence_for_year(birth_date: date, year: int) -> date:
    """Return the birthday date for a year using the shared Feb-29 policy."""
    if birth_date.month == 2 and birth_date.day == 29 and not calendar.isleap(year):
        return date(year, 2, 28)
    return date(year, birth_date.month, birth_date.day)


class PushCampaignService:
    def __init__(self, session: Session, delivery: PushDeliveryPort) -> None:
        self.session = session
        self.delivery = delivery

    @property
    def provider_configured(self) -> bool:
        settings = get_settings()
        return settings.push_notifications_enabled and settings.fcm_is_configured and self.delivery.__class__.__name__ not in {
            'DevNullPushDeliveryService',
            'UnavailablePushDeliveryService',
        }

    def list(self) -> list[PushCampaignResponse]:
        return [self.serialize(c) for c in self.session.scalars(select(PushCampaign).order_by(PushCampaign.created_at.desc())).all()]

    def get(self, campaign_id: str) -> PushCampaignResponse:
        return self.serialize(self._get(campaign_id))

    def create(self, payload: PushCampaignCreateRequest, admin_id: str) -> PushCampaignResponse:
        scheduled = self._normalize_scheduled(payload.scheduled_at)
        campaign = PushCampaign(
            internal_name=payload.internal_name.strip(), title=payload.title.strip(), body=payload.body.strip(),
            audience_type=payload.audience.type,
            audience_config=payload.audience.model_dump(exclude_none=True, exclude={'type'}),
            destination=payload.destination, destination_payload={},
            status='scheduled' if scheduled else 'draft', scheduled_at=scheduled, created_by_admin_id=admin_id,
        )
        self.session.add(campaign)
        self.session.commit()
        self.session.refresh(campaign)
        return self.serialize(campaign)

    def update(self, campaign_id: str, payload: PushCampaignUpdateRequest) -> PushCampaignResponse:
        campaign = self._get(campaign_id)
        if campaign.origin == 'system_birthday':
            raise DomainHTTPException(
                code='system_campaign_not_editable',
                message='Системную birthday-кампанию нельзя редактировать.',
                status_code=409,
            )
        if campaign.status not in {'draft', 'scheduled'}:
            raise DomainHTTPException(code='campaign_not_editable', message='Кампания уже запущена или завершена.', status_code=409)
        changes = payload.model_dump(exclude_unset=True)
        if 'scheduled_at' in changes:
            campaign.scheduled_at = self._normalize_scheduled(changes.pop('scheduled_at'))
            campaign.status = 'scheduled' if campaign.scheduled_at else 'draft'
        if 'audience' in changes:
            audience = changes.pop('audience')
            campaign.audience_type = audience['type']
            campaign.audience_config = {k: v for k, v in audience.items() if k != 'type' and v is not None}
        for field in ('internal_name', 'title', 'body', 'destination'):
            if field in changes and changes[field] is not None:
                setattr(campaign, field, str(changes[field]).strip())
        self.session.commit()
        return self.serialize(campaign)

    def preview(self, audience: PushCampaignAudience) -> PushCampaignPreviewResponse:
        users, devices = self._resolve_audience(audience)
        return PushCampaignPreviewResponse(targeted_users=len(users), targeted_devices=len(devices))

    def send(self, campaign_id: str) -> PushCampaignResponse:
        if not self.provider_configured:
            raise DomainHTTPException(
                code='push_not_configured',
                message='FCM не настроен: отправка кампаний недоступна.',
                status_code=503,
            )
        campaign = self._get(campaign_id)
        if campaign.status in {'sent', 'cancelled'}:
            raise DomainHTTPException(code='campaign_terminal', message='Завершённую кампанию нельзя отправить повторно.', status_code=409)
        self._start_snapshot(campaign_id)
        self._deliver_campaign(campaign_id)
        return self.get(campaign_id)

    def cancel(self, campaign_id: str) -> PushCampaignResponse:
        campaign = self._get(campaign_id)
        if campaign.status not in {'draft', 'scheduled'}:
            raise DomainHTTPException(code='campaign_not_cancellable', message='Эту кампанию нельзя отменить.', status_code=409)
        campaign.status = 'cancelled'
        campaign.cancelled_at = datetime.now(UTC)
        self.session.commit()
        return self.serialize(campaign)

    def process_due(self) -> int:
        now = datetime.now(UTC)
        ids = self.session.scalars(select(PushCampaign.id).where(
            or_(and_(PushCampaign.status == 'scheduled', PushCampaign.scheduled_at <= now), PushCampaign.status == 'processing')
        ).order_by(PushCampaign.scheduled_at.nullsfirst()).limit(25)).all()
        for campaign_id in ids:
            try:
                if not self.provider_configured:
                    logger.warning('push campaign skipped: FCM is not configured campaign_id=%s', campaign_id)
                    continue
                self._start_snapshot(campaign_id)
                self._deliver_campaign(campaign_id)
            except Exception:  # noqa: BLE001
                logger.exception('push campaign processing failed campaign_id=%s', campaign_id)
                self.session.rollback()
        return len(ids)

    def _start_snapshot(self, campaign_id: str) -> None:
        campaign = self.session.scalar(select(PushCampaign).where(PushCampaign.id == campaign_id).with_for_update())
        if campaign is None:
            raise NotFoundException(code='campaign_not_found', message='Кампания не найдена.')
        if campaign.status in {'sent', 'cancelled'}:
            return
        if campaign.status == 'scheduled' and campaign.scheduled_at and campaign.scheduled_at > datetime.now(UTC):
            raise DomainHTTPException(code='campaign_not_due', message='Кампания ещё не наступила.', status_code=409)
        existing = self.session.scalar(select(func.count()).select_from(PushCampaignDelivery).where(PushCampaignDelivery.campaign_id == campaign.id))
        campaign.status = 'processing'
        campaign.started_at = campaign.started_at or datetime.now(UTC)
        if not existing:
            audience = PushCampaignAudience(type=campaign.audience_type, **campaign.audience_config)
            _, devices = self._resolve_audience(audience)
            for user_id, device in devices:
                self.session.add(PushCampaignDelivery(campaign_id=campaign.id, mobile_user_id=user_id, device_id=device.id, token_snapshot=device.push_token))
            campaign.targeted_users = len({u for u, _ in devices})
            campaign.targeted_devices = len(devices)
        self.session.commit()

    def _deliver_campaign(self, campaign_id: str) -> None:
        campaign = self.session.get(PushCampaign, campaign_id)
        if campaign is None or campaign.status in {'sent', 'cancelled'}:
            return
        while True:
            delivery = self._claim_delivery(campaign_id)
            if delivery is None:
                break
            result = self.delivery.send(
                device_token=delivery.token_snapshot, title=campaign.title, body=campaign.body,
                data={'type': 'campaign', 'campaignId': campaign.id, 'destination': campaign.destination},
            )
            self._record_delivery(delivery.id, result)
        self._finish_campaign(campaign_id)

    def _claim_delivery(self, campaign_id: str) -> PushCampaignDelivery | None:
        stale = datetime.now(UTC) - STALE_SENDING_AFTER
        delivery = self.session.scalar(select(PushCampaignDelivery).where(
            PushCampaignDelivery.campaign_id == campaign_id,
            or_(PushCampaignDelivery.status == 'pending', and_(PushCampaignDelivery.status == 'sending', PushCampaignDelivery.updated_at < stale)),
            PushCampaignDelivery.attempt_count < MAX_ATTEMPTS,
        ).order_by(PushCampaignDelivery.created_at).with_for_update(skip_locked=True))
        if delivery is None:
            self.session.commit()
            return None
        delivery.status = 'sending'
        delivery.attempt_count += 1
        self.session.commit()
        return delivery

    def _record_delivery(self, delivery_id: str, result) -> None:
        delivery = self.session.get(PushCampaignDelivery, delivery_id)
        if delivery is None:
            return
        if result.success:
            delivery.status = 'sent'; delivery.sent_at = datetime.now(UTC); delivery.provider_message_id = result.provider_message_id
        else:
            delivery.last_error_code = result.error_code; delivery.last_error_message = (result.error_message or '')[:255]
            if result.error_code in {'unregistered', 'invalid_token'}:
                delivery.status = 'failed'
                if delivery.device_id:
                    self.session.execute(update(MobileNotificationDevice).where(MobileNotificationDevice.id == delivery.device_id).values(notifications_enabled=False))
            elif delivery.attempt_count >= MAX_ATTEMPTS:
                delivery.status = 'failed'
            else:
                delivery.status = 'pending'
        self.session.commit()

    def _finish_campaign(self, campaign_id: str) -> None:
        campaign = self.session.scalar(select(PushCampaign).where(PushCampaign.id == campaign_id).with_for_update())
        if campaign is None:
            return
        deliveries = self.session.scalars(select(PushCampaignDelivery).where(PushCampaignDelivery.campaign_id == campaign_id)).all()
        if any(d.status in {'pending', 'sending'} for d in deliveries):
            self.session.commit(); return
        campaign.sent_count = sum(d.status == 'sent' for d in deliveries)
        campaign.failed_count = sum(d.status == 'failed' for d in deliveries)
        campaign.status = 'failed' if campaign.failed_count and not campaign.sent_count else 'sent'
        campaign.sent_at = datetime.now(UTC) if campaign.status == 'sent' else None
        self.session.commit()

    def _resolve_audience(self, audience: PushCampaignAudience) -> tuple[list[str], list[tuple[str, MobileNotificationDevice]]]:
        query = select(MobileUser.id, MobileNotificationDevice).join(MobileNotificationDevice, MobileNotificationDevice.mobile_user_id == MobileUser.id).where(
            MobileUser.is_active.is_(True), MobileNotificationDevice.notifications_enabled.is_(True),
            MobileNotificationDevice.permission_status.not_in(['denied', 'unavailable']),
        )
        if audience.type == 'birthday_in_days':
            target = birthday_target_date(datetime.now(UTC), audience.days_before_birthday or 0)
            month_match = extract('month', MobileChild.birth_date) == target.month
            day_match = extract('day', MobileChild.birth_date) == target.day
            if target.month == 2 and target.day == 28:
                day_match = day_match | extract('day', MobileChild.birth_date) == 29
            query = query.join(MobileChild, MobileChild.user_id == MobileUser.id).where(month_match, day_match)
        elif audience.type == 'user':
            query = query.where(MobileUser.id == audience.user_id)
        rows = self.session.execute(query.distinct()).all()
        devices = [(row[0], row[1]) for row in rows]
        return sorted({u for u, _ in devices}), devices

    def create_system_birthday_campaign(
        self,
        *,
        user_id: str,
        internal_name: str,
        title: str,
        body: str,
    ) -> PushCampaign:
        """Create an immutable user-scoped campaign in the caller transaction."""
        campaign = PushCampaign(
            internal_name=internal_name,
            title=title,
            body=body,
            audience_type='user',
            audience_config={'user_id': user_id},
            destination='birthdays',
            destination_payload={},
            status='draft',
            created_by_admin_id=None,
            origin='system_birthday',
        )
        self.session.add(campaign)
        self.session.flush()
        return campaign

    def process_existing(self, campaign_id: str) -> PushCampaignResponse:
        """Resume a system campaign after a crash or partial execution."""
        if not self.provider_configured:
            return self.get(campaign_id)
        campaign = self._get(campaign_id)
        if campaign.status in {'sent', 'cancelled'}:
            return self.serialize(campaign)
        self._start_snapshot(campaign_id)
        self._deliver_campaign(campaign_id)
        return self.get(campaign_id)

    def _get(self, campaign_id: str) -> PushCampaign:
        item = self.session.get(PushCampaign, campaign_id)
        if item is None:
            raise NotFoundException(code='campaign_not_found', message='Кампания не найдена.')
        return item

    def _normalize_scheduled(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        normalized = value.astimezone(UTC)
        if normalized <= datetime.now(UTC):
            raise DomainHTTPException(code='invalid_schedule', message='Дата отправки должна быть в будущем.')
        return normalized

    def serialize(self, campaign: PushCampaign) -> PushCampaignResponse:
        audience = PushCampaignAudience(type=campaign.audience_type, **campaign.audience_config)
        return PushCampaignResponse(
            id=campaign.id, internal_name=campaign.internal_name, title=campaign.title, body=campaign.body,
            audience=audience, destination=campaign.destination, origin=campaign.origin, status=campaign.status,
            scheduled_at=campaign.scheduled_at, started_at=campaign.started_at, sent_at=campaign.sent_at,
            cancelled_at=campaign.cancelled_at, targeted_users=campaign.targeted_users, targeted_devices=campaign.targeted_devices,
            sent_count=campaign.sent_count, failed_count=campaign.failed_count, push_provider_configured=self.provider_configured,
        )
