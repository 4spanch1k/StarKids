import logging

from .delivery_port import PushDeliveryPort
from .delivery_result import PushDeliveryResult

logger = logging.getLogger(__name__)


class DevNullPushDeliveryService(PushDeliveryPort):
    """
    No-op push delivery used when FCM credentials are not configured.

    Every call returns a failed result with ``error_code='not_configured'``
    and logs a warning.  This makes it safe to wire trigger points without
    crashing when Firebase credentials are absent (e.g. local development).

    To enable real delivery:
    1. Create a Firebase project and download the service account JSON.
    2. Set FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY in .env.
    3. The application factory will automatically switch to FcmPushDeliveryService.
    """

    def send(
        self,
        *,
        device_token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> PushDeliveryResult:
        logger.warning(
            'Push delivery is not configured (FCM credentials missing). '
            'Message "%s" was NOT delivered to token %s...',
            title,
            device_token[:8],
        )
        return PushDeliveryResult.failed(
            device_token,
            error_code='not_configured',
            error_message='FCM credentials are not set. See DevNullPushDeliveryService.',
        )
