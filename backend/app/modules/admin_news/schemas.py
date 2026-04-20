from datetime import datetime, timezone

from pydantic import BaseModel, Field, field_serializer


class AdminNewsResponse(BaseModel):
    id: str
    title: str
    image_url: str
    description: str | None = None
    is_active: bool
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


class AdminNewsCreateRequest(BaseModel):
    title: str = Field(min_length=2, max_length=255)
    image_url: str = Field(min_length=1, max_length=512)
    description: str | None = Field(default=None, max_length=5000)
    is_active: bool = True


class AdminNewsUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=255)
    image_url: str | None = Field(default=None, min_length=1, max_length=512)
    description: str | None = Field(default=None, max_length=5000)
    is_active: bool | None = None


class AdminNewsImageUploadResponse(BaseModel):
    image_url: str
