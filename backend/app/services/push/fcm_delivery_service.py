from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from .delivery_port import PushDeliveryPort
from .delivery_result import PushDeliveryResult

if TYPE_CHECKING:
    import firebase_admin

logger = logging.getLogger(__name__)


class FcmPushDeliveryService(PushDeliveryPort):
    """
    Sends push notifications via Firebase Cloud Messaging (FCM HTTP v1 API).

    Requires ``firebase-admin`` to be installed and a Firebase service account
    with the following credentials configured in .env:
    - FCM_PROJECT_ID
    - FCM_CLIENT_EMAIL
    - FCM_PRIVATE_KEY

    ``firebase-admin`` is imported lazily so the rest of the application can
    start even if the package is not installed (tests, minimal environments).
    """

    def __init__(self, firebase_app: firebase_admin.App) -> None:  # type: ignore[name-defined]
        self._app = firebase_app

    @classmethod
    def from_service_account_fields(
        cls,
        *,
        project_id: str,
        client_email: str,
        private_key: str,
    ) -> FcmPushDeliveryService:
        """
        Build and register a Firebase app from individual service account fields.

        The private_key may contain literal ``\\n`` sequences as stored in .env
        files; they are normalized to real newlines automatically.

        Raises :class:`ImportError` if ``firebase-admin`` is not installed.
        """
        try:
            import firebase_admin  # noqa: PLC0415
            from firebase_admin import credentials  # noqa: PLC0415
        except ImportError as exc:
            raise ImportError(
                'firebase-admin is required for FCM push delivery. '
                'Install it with: pip install firebase-admin==6.6.0'
            ) from exc

        normalized_key = private_key.replace('\\n', '\n')
        service_account_info = {
            'type': 'service_account',
            'project_id': project_id,
            'private_key': normalized_key,
            'client_email': client_email,
            'token_uri': 'https://oauth2.googleapis.com/token',
        }
        cred = credentials.Certificate(service_account_info)
        app_name = f'starkids-{project_id}'
        try:
            firebase_app = firebase_admin.get_app(app_name)
        except ValueError:
            firebase_app = firebase_admin.initialize_app(cred, name=app_name)
        return cls(firebase_app)

    def send(
        self,
        *,
        device_token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> PushDeliveryResult:
        try:
            from firebase_admin import messaging  # noqa: PLC0415
        except ImportError as exc:
            raise ImportError(
                'firebase-admin is required for FCM push delivery.'
            ) from exc

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=device_token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(sound='default'),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound='default'),
                ),
            ),
        )
        try:
            messaging.send(message, app=self._app)
            logger.info('FCM push sent to token=%s...', device_token[:8])
            return PushDeliveryResult.ok(device_token)
        except messaging.UnregisteredError:
            logger.warning('FCM token unregistered: %s...', device_token[:8])
            return PushDeliveryResult.failed(
                device_token,
                error_code='unregistered',
                error_message='Device token is no longer valid.',
            )
        except Exception as exc:  # noqa: BLE001
            logger.error('FCM send failed: %s', exc)
            return PushDeliveryResult.failed(
                device_token,
                error_code='send_error',
                error_message=str(exc),
            )
