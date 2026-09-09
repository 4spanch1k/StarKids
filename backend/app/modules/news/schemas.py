from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, field_serializer


class MobileNewsItem(BaseModel):
    id: str
    title: str
    image_url: str
    description: str | None = None
    created_at: datetime

    @field_serializer('created_at')
    def serialize_created_at(self, value: datetime) -> str:
        normalized = value if value.tzinfo is not None else value.replace(
            tzinfo=timezone.utc,
        )
        return normalized.astimezone(timezone.utc).isoformat().replace(
            '+00:00',
            'Z',
        )


NewsEventType = Literal['view', 'click']


class MobileNewsEventRequest(BaseModel):
    event_type: NewsEventType
