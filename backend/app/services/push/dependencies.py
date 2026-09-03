import logging

from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.config.settings import get_settings
from ...core.database.session import get_db_session
from ...db.repositories.mobile_notification_device_repository import (
    MobileNotificationDeviceRepository,
)
from .delivery_port import PushDeliveryPort
from .dev_null_delivery_service import DevNullPushDeliveryService
from .fcm_delivery_service import FcmPushDeliveryService
from .push_service import PushService

logger = logging.getLogger(__name__)

_cached_delivery: PushDeliveryPort | None = None


def get_push_delivery() -> PushDeliveryPort:
    """
    Returns the application-level push delivery implementation.

    Result is cached after first call.  Uses :class:`FcmPushDeliveryService`
    when FCM credentials are present in settings, otherwise falls back to
    :class:`DevNullPushDeliveryService` which logs a warning on every call.
    """
    global _cached_delivery  # noqa: PLW0603
    if _cached_delivery is not None:
        return _cached_delivery

    settings = get_settings()
    if settings.fcm_is_configured:
        try:
            _cached_delivery = FcmPushDeliveryService.from_service_account_fields(
                project_id=settings.fcm_project_id,  # type: ignore[arg-type]
                client_email=settings.fcm_client_email,  # type: ignore[arg-type]
                private_key=settings.fcm_private_key,  # type: ignore[arg-type]
            )
            logger.info('Push delivery: FcmPushDeliveryService initialized.')
        except ImportError:
            logger.error(
                'firebase-admin is not installed. '
                'Run: pip install firebase-admin==6.6.0'
            )
            _cached_delivery = DevNullPushDeliveryService()
        except Exception as exc:  # noqa: BLE001
            logger.error('Failed to initialize FCM delivery service: %s', exc)
            _cached_delivery = DevNullPushDeliveryService()
    else:
        logger.info(
            'Push delivery: FCM credentials not set, using DevNullPushDeliveryService. '
            'Set FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY to enable real delivery.',
        )
        _cached_delivery = DevNullPushDeliveryService()

    return _cached_delivery


def get_push_service(
    session: Session = Depends(get_db_session),
    delivery: PushDeliveryPort = Depends(get_push_delivery),
) -> PushService:
    return PushService(
        delivery=delivery,
        device_repository=MobileNotificationDeviceRepository(session),
    )
