from datetime import datetime, timezone

from ...db.models.mobile_session import MobileSession
from ...db.models.mobile_user import MobileUser
from ...db.repositories.mobile_notification_device_repository import (
    MobileNotificationDeviceRepository,
)
from ...db.repositories.mobile_notification_repository import (
    MobileNotificationRepository,
)
from ..mobile_auth.service import MobileAuthService
from .schemas import NotificationItem
from .schemas import (
    MobileNotificationDeviceResponse,
    MobileNotificationDeviceUpsertRequest,
)


class NotificationService:
    def __init__(
        self,
        *,
        device_repository: MobileNotificationDeviceRepository | None = None,
        notification_repository: MobileNotificationRepository | None = None,
    ) -> None:
        self.device_repository = device_repository
        self.notification_repository = notification_repository

    def list_notifications(
        self,
        *,
        limit: int = 10,
        offset: int = 0,
    ) -> list[NotificationItem]:
        if self.notification_repository is None:
            return [
                NotificationItem(
                    id='notification-1',
                    news_id=None,
                    type='system',
                    title='Welcome to Star Kids',
                    description=None,
                    image_url=None,
                    created_at=datetime.now(timezone.utc),
                    is_read=False,
                )
            ]

        items = self.notification_repository.list_mobile(limit=limit, offset=offset)
        return [
            NotificationItem(
                id=item.id,
                news_id=item.news_id,
                type=item.notification_type,  # type: ignore[arg-type]
                title=item.title,
                description=item.description,
                image_url=item.image_url,
                created_at=item.created_at,
                is_read=False,
            )
            for item in items
        ]

    def register_device(
        self,
        *,
        current_user: MobileUser,
        current_session: MobileSession,
        payload: MobileNotificationDeviceUpsertRequest,
    ) -> MobileNotificationDeviceResponse:
        self._ensure_current_session_belongs_to_user(current_user, current_session)
        repository = self._require_device_repository()
        device = repository.upsert(
            mobile_user_id=current_user.id,
            mobile_session_id=current_session.id,
            platform=payload.platform,
            push_token=payload.push_token,
            permission_status=payload.permission_status,
            notifications_enabled=payload.notifications_enabled,
        )
        return MobileNotificationDeviceResponse(
            id=device.id,
            platform=device.platform,
            push_token=device.push_token,
            permission_status=device.permission_status,
            notifications_enabled=device.notifications_enabled,
            created_at=device.created_at,
            updated_at=device.updated_at,
        )

    def remove_device(
        self,
        *,
        current_user: MobileUser,
        current_session: MobileSession,
    ) -> None:
        self._ensure_current_session_belongs_to_user(current_user, current_session)
        repository = self._require_device_repository()
        repository.delete_for_mobile_session(current_session.id)

    def _require_device_repository(self) -> MobileNotificationDeviceRepository:
        if self.device_repository is None:
            raise RuntimeError('Notification device repository is not configured.')
        return self.device_repository

    def _ensure_current_session_belongs_to_user(
        self,
        current_user: MobileUser,
        current_session: MobileSession,
    ) -> None:
        if current_session.mobile_user_id != current_user.id:
            raise MobileAuthService.authentication_required_exception()
