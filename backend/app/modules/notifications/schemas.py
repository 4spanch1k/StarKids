from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, Field, field_serializer

NotificationType = Literal['news', 'system', 'promo']


class NotificationItem(BaseModel):
    id: str
    news_id: str | None = None
    type: NotificationType
    title: str
    description: str | None = None
    image_url: str | None = None
    created_at: datetime
    is_read: bool

    @field_serializer('created_at')
    def serialize_created_at(self, value: datetime) -> str:
        normalized = value if value.tzinfo is not None else value.replace(
            tzinfo=timezone.utc,
        )
        return normalized.astimezone(timezone.utc).isoformat().replace(
            '+00:00',
            'Z',
        )


NotificationDevicePlatform = Literal['android', 'ios', 'macos', 'web']
NotificationPermissionStatus = Literal[
    'unknown',
    'granted',
    'denied',
    'unavailable',
]


class MobileNotificationDeviceUpsertRequest(BaseModel):
    platform: NotificationDevicePlatform
    push_token: str = Field(min_length=1, max_length=512)
    permission_status: NotificationPermissionStatus
    notifications_enabled: bool = True


class MobileNotificationDeviceResponse(BaseModel):
    id: str
    platform: NotificationDevicePlatform
    push_token: str
    permission_status: NotificationPermissionStatus
    notifications_enabled: bool
    created_at: datetime
    updated_at: datetime

    @field_serializer('created_at', 'updated_at')
    def serialize_timestamp(self, value: datetime) -> str:
        normalized = value if value.tzinfo is not None else value.replace(
            tzinfo=timezone.utc,
        )
        return normalized.astimezone(timezone.utc).isoformat().replace(
            '+00:00',
            'Z',
        )
