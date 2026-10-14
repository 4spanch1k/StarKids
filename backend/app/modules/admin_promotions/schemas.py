from datetime import datetime, timezone

from pydantic import BaseModel, Field, field_serializer, field_validator, model_validator


def _normalize_timestamp(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _serialize_timestamp(value: datetime | None) -> str | None:
    if value is None:
        return None
    normalized = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
    return normalized.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')


class AdminPromotionListQuery(BaseModel):
    branch_id: str | None = Field(default=None, min_length=1, max_length=32)
    is_active: bool | None = None
    is_published: bool | None = None


class AdminPromotionResponse(BaseModel):
    id: str
    title: str
    description: str
    badge_label: str
    image_url: str | None = None
    branch_ids: list[str] = Field(default_factory=list)
    cta_label: str
    display_order: int
    is_active: bool
    is_published: bool
    start_at: datetime | None = None
    end_at: datetime | None = None

    @field_serializer('start_at', 'end_at')
    def serialize_datetime(self, value: datetime | None) -> str | None:
        return _serialize_timestamp(value)


class AdminPromotionCreateRequest(BaseModel):
    title: str = Field(min_length=2, max_length=255)
    description: str = Field(min_length=10, max_length=5000)
    badge_label: str = Field(min_length=1, max_length=64)
    image_url: str | None = Field(default=None, max_length=512)
    branch_ids: list[str] = Field(default_factory=list)
    cta_label: str = Field(min_length=1, max_length=64)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True
    is_published: bool = False
    start_at: datetime | None = None
    end_at: datetime | None = None

    @field_validator('start_at', 'end_at')
    @classmethod
    def normalize_dates(cls, value: datetime | None) -> datetime | None:
        return _normalize_timestamp(value)

    @model_validator(mode='after')
    def validate_date_range(self) -> 'AdminPromotionCreateRequest':
        if self.start_at is not None and self.end_at is not None and self.end_at <= self.start_at:
            raise ValueError('end_at must be later than start_at')
        return self


class AdminPromotionUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=255)
    description: str | None = Field(default=None, min_length=10, max_length=5000)
    badge_label: str | None = Field(default=None, min_length=1, max_length=64)
    image_url: str | None = Field(default=None, max_length=512)
    branch_ids: list[str] | None = None
    cta_label: str | None = Field(default=None, min_length=1, max_length=64)
    display_order: int | None = Field(default=None, ge=0, le=1000)
    is_active: bool | None = None
    is_published: bool | None = None
    start_at: datetime | None = None
    end_at: datetime | None = None

    @field_validator('start_at', 'end_at')
    @classmethod
    def normalize_dates(cls, value: datetime | None) -> datetime | None:
        return _normalize_timestamp(value)

    @model_validator(mode='after')
    def validate_date_range(self) -> 'AdminPromotionUpdateRequest':
        if self.start_at is not None and self.end_at is not None and self.end_at <= self.start_at:
            raise ValueError('end_at must be later than start_at')
        return self
