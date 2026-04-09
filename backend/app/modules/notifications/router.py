from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.mobile_notification_device_repository import (
    MobileNotificationDeviceRepository,
)
from ..mobile_auth.dependencies import (
    AuthenticatedMobileContext,
    get_current_mobile_auth_context,
)
from .schemas import NotificationItem
from .schemas import (
    MobileNotificationDeviceResponse,
    MobileNotificationDeviceUpsertRequest,
)
from .service import NotificationService

router = APIRouter()
service = NotificationService()


def get_notification_service(
    session: Session = Depends(get_db_session),
) -> NotificationService:
    return NotificationService(
        device_repository=MobileNotificationDeviceRepository(session),
    )


@router.get('/notifications', response_model=list[NotificationItem])
def list_notifications() -> list[NotificationItem]:
    return service.list_notifications()


@router.put(
    '/me/notification-device',
    response_model=MobileNotificationDeviceResponse,
    responses={401: {'model': ErrorResponse}, 422: {'model': ErrorResponse}},
)
def register_mobile_notification_device(
    payload: MobileNotificationDeviceUpsertRequest,
    current_context: AuthenticatedMobileContext = Depends(
        get_current_mobile_auth_context,
    ),
    service: NotificationService = Depends(get_notification_service),
) -> MobileNotificationDeviceResponse:
    return service.register_device(
        current_user=current_context.user,
        current_session=current_context.session,
        payload=payload,
    )


@router.delete(
    '/me/notification-device',
    status_code=status.HTTP_204_NO_CONTENT,
    responses={401: {'model': ErrorResponse}},
)
def remove_mobile_notification_device(
    current_context: AuthenticatedMobileContext = Depends(
        get_current_mobile_auth_context,
    ),
    service: NotificationService = Depends(get_notification_service),
) -> Response:
    service.remove_device(
        current_user=current_context.user,
        current_session=current_context.session,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
