from ...db.models.mobile_session import MobileSession
from ...db.models.mobile_user import MobileUser
from ...db.repositories.mobile_notification_device_repository import (
    MobileNotificationDeviceRepository,
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
    ) -> None:
        self.device_repository = device_repository

    def list_notifications(self) -> list[NotificationItem]:
        return [
            NotificationItem(
                id='notification-1',
                title='Welcome to Star Kids',
                is_read=False,
            )
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
