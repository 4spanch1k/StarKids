from datetime import datetime, timezone
from urllib.parse import urlparse

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_serializer,
    field_validator,
    model_validator,
)


def _normalize_timestamp(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is not None:
        return value.astimezone(timezone.utc)
    return value.replace(tzinfo=timezone.utc)


def _is_allowed_image_url(value: str) -> bool:
    if value.startswith('/media/'):
        return True
    parsed = urlparse(value)
    return parsed.scheme in {'http', 'https'} and bool(parsed.netloc)


class AdminNewsResponse(BaseModel):
    id: str
    title: str
    image_url: str
    description: str | None = None
    is_active: bool
    display_order: int
    publish_at: datetime | None = None
    created_at: datetime

    @field_serializer('publish_at', 'created_at')
    def serialize_datetime(self, value: datetime | None) -> str | None:
        if value is None:
            return None
        normalized = value if value.tzinfo is not None else value.replace(
            tzinfo=timezone.utc,
        )
        return normalized.astimezone(timezone.utc).isoformat().replace(
            '+00:00',
            'Z',
        )


class AdminNewsCreateRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    title: str = Field(min_length=2, max_length=80)
    image_url: str = Field(min_length=1, max_length=512)
    description: str = Field(min_length=3, max_length=5000)
    is_active: bool = True
    display_order: int = Field(default=0, ge=0, le=1000)
    publish_at: datetime | None = None

    @field_validator('image_url')
    @classmethod
    def validate_image_url(cls, value: str) -> str:
        if not _is_allowed_image_url(value):
            raise ValueError('Укажите корректную ссылку на изображение.')
        return value

    @field_validator('publish_at')
    @classmethod
    def normalize_publish_at(cls, value: datetime | None) -> datetime | None:
        return _normalize_timestamp(value)


class AdminNewsUpdateRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    title: str | None = Field(default=None, min_length=2, max_length=80)
    image_url: str | None = Field(default=None, min_length=1, max_length=512)
    description: str | None = Field(default=None, min_length=3, max_length=5000)
    is_active: bool | None = None
    display_order: int | None = Field(default=None, ge=0, le=1000)
    publish_at: datetime | None = None

    @field_validator('image_url')
    @classmethod
    def validate_optional_image_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if not _is_allowed_image_url(value):
            raise ValueError('Укажите корректную ссылку на изображение.')
        return value

    @field_validator('publish_at')
    @classmethod
    def normalize_optional_publish_at(
        cls,
        value: datetime | None,
    ) -> datetime | None:
        return _normalize_timestamp(value)

    @model_validator(mode='after')
    def validate_description_presence(self) -> 'AdminNewsUpdateRequest':
        if 'description' in self.model_fields_set and self.description is None:
            raise ValueError('Описание новости нельзя очищать до пустого значения.')
        return self


class AdminNewsImageUploadResponse(BaseModel):
    image_url: str


class AdminNewsStatsResponse(BaseModel):
    views_count: int
    clicks_count: int
    ctr: float


class AdminNewsTopStatsItem(BaseModel):
    news_id: str
    title: str
    image_url: str
    views_count: int
    clicks_count: int
    ctr: float


class AdminNewsTopStatsResponse(BaseModel):
    last_24_hours: list[AdminNewsTopStatsItem]
    last_7_days: list[AdminNewsTopStatsItem]
