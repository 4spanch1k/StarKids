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
from .unavailable_delivery_service import UnavailablePushDeliveryService

logger = logging.getLogger(__name__)

_cached_delivery: PushDeliveryPort | None = None


def get_push_delivery() -> PushDeliveryPort:
    """
    Returns the application-level push delivery implementation.

    Result is cached after first call.  DevNull is intentionally limited to
    development/test environments; production-like environments fail closed
    with :class:`UnavailablePushDeliveryService` when FCM is unavailable.
    """
    global _cached_delivery  # noqa: PLW0603
    if _cached_delivery is not None:
        return _cached_delivery

    settings = get_settings()
    if settings.push_notifications_enabled and settings.fcm_is_configured:
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
            _cached_delivery = _unavailable_or_dev_null(settings)
        except Exception as exc:  # noqa: BLE001
            logger.error('Failed to initialize FCM delivery service: %s', exc)
            _cached_delivery = _unavailable_or_dev_null(settings)
    else:
        message = (
            'Push delivery is disabled or FCM credentials are not configured. '
            'Set PUSH_NOTIFICATIONS_ENABLED=true and FCM credentials to enable delivery.'
        )
        if settings.app_env.lower() in {'development', 'test'}:
            logger.info('%s Using development DevNull provider.', message)
            _cached_delivery = DevNullPushDeliveryService()
        else:
            logger.error('%s Production fails closed.', message)
            _cached_delivery = UnavailablePushDeliveryService()

    return _cached_delivery


def _unavailable_or_dev_null(settings) -> PushDeliveryPort:
    """Keep fake delivery out of production, including init failures."""
    if settings.app_env.lower() in {'development', 'test'}:
        return DevNullPushDeliveryService()
    return UnavailablePushDeliveryService()


def get_push_service(
    session: Session = Depends(get_db_session),
    delivery: PushDeliveryPort = Depends(get_push_delivery),
) -> PushService:
    return PushService(
        delivery=delivery,
        device_repository=MobileNotificationDeviceRepository(session),
    )
