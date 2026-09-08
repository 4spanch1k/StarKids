from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, model_validator

from ..visit_segmentation import VisitAudienceSegment

AudienceType = Literal['all_users', 'birthday_in_days', 'user', 'visit_segment']
Destination = Literal['home', 'tickets', 'birthdays', 'promotions', 'profile']


class PushCampaignAudience(BaseModel):
    type: AudienceType
    days_before_birthday: int | None = Field(default=None, ge=1, le=365)
    user_id: str | None = Field(default=None, min_length=1, max_length=32)
    visit_segment: VisitAudienceSegment | None = None

    @model_validator(mode='after')
    def validate_config(self) -> 'PushCampaignAudience':
        if self.type == 'birthday_in_days' and self.days_before_birthday is None:
            raise ValueError('days_before_birthday is required for birthday audience')
        if self.type == 'user' and self.user_id is None:
            raise ValueError('user_id is required for user audience')
        if self.type == 'visit_segment' and self.visit_segment is None:
            raise ValueError('visit_segment is required for visit segment audience')
        if self.type != 'birthday_in_days' and self.days_before_birthday is not None:
            raise ValueError('days_before_birthday is only valid for birthday audience')
        if self.type != 'user' and self.user_id is not None:
            raise ValueError('user_id is only valid for user audience')
        if self.type != 'visit_segment' and self.visit_segment is not None:
            raise ValueError('visit_segment is only valid for visit segment audience')
        return self


class PushCampaignCreateRequest(BaseModel):
    internal_name: str = Field(min_length=2, max_length=150)
    title: str = Field(min_length=1, max_length=100)
    body: str = Field(min_length=1, max_length=500)
    audience: PushCampaignAudience
    destination: Destination
    scheduled_at: datetime | None = None

    @model_validator(mode='after')
    def validate_scheduled_at(self) -> 'PushCampaignCreateRequest':
        if self.scheduled_at is not None and self.scheduled_at.tzinfo is None:
            raise ValueError('scheduled_at must include a timezone')
        return self


class PushCampaignUpdateRequest(BaseModel):
    internal_name: str | None = Field(default=None, min_length=2, max_length=150)
    title: str | None = Field(default=None, min_length=1, max_length=100)
    body: str | None = Field(default=None, min_length=1, max_length=500)
    audience: PushCampaignAudience | None = None
    destination: Destination | None = None
    scheduled_at: datetime | None = None


class PushCampaignResponse(BaseModel):
    id: str
    internal_name: str
    title: str
    body: str
    audience: PushCampaignAudience
    destination: Destination
    origin: Literal['manual', 'system_birthday']
    status: str
    scheduled_at: datetime | None
    started_at: datetime | None
    sent_at: datetime | None
    cancelled_at: datetime | None
    targeted_users: int
    targeted_devices: int
    sent_count: int
    failed_count: int
    push_provider_configured: bool


class PushCampaignPreviewRequest(BaseModel):
    audience: PushCampaignAudience


class PushCampaignPreviewResponse(BaseModel):
    targeted_users: int
    targeted_devices: int
