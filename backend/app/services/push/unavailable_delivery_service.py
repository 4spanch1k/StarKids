"""Explicit fail-closed push provider for non-development environments."""

from .delivery_port import PushDeliveryPort
from .delivery_result import PushDeliveryResult


class UnavailablePushDeliveryService(PushDeliveryPort):
    """Never reports delivery success when push infrastructure is unavailable."""

    def send(
        self,
        *,
        device_token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> PushDeliveryResult:
        return PushDeliveryResult.failed(
            device_token,
            error_code='not_configured',
            error_message='Push provider is not configured.',
        )
