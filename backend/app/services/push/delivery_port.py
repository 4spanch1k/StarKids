from abc import ABC, abstractmethod

from .delivery_result import PushDeliveryResult


class PushDeliveryPort(ABC):
    """Abstract interface for sending push notifications to individual devices."""

    @abstractmethod
    def send(
        self,
        *,
        device_token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> PushDeliveryResult:
        """Send a push notification to a single FCM device token."""
        ...
