from dataclasses import dataclass


@dataclass(frozen=True)
class PushDeliveryResult:
    success: bool
    device_token: str
    error_code: str | None = None
    error_message: str | None = None
    provider_message_id: str | None = None

    @classmethod
    def ok(cls, device_token: str, provider_message_id: str | None = None) -> 'PushDeliveryResult':
        return cls(success=True, device_token=device_token, provider_message_id=provider_message_id)

    @classmethod
    def failed(
        cls,
        device_token: str,
        error_code: str,
        error_message: str | None = None,
    ) -> 'PushDeliveryResult':
        return cls(
            success=False,
            device_token=device_token,
            error_code=error_code,
            error_message=error_message,
        )
