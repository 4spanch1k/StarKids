from __future__ import annotations

from datetime import date, datetime, timezone

from pydantic import BaseModel, ConfigDict, EmailStr, field_serializer, field_validator

from ..mobile_request_history.schemas import (
    MobileRequestHistoryBranchSummary,
    MobileRequestHistoryPackageSummary,
)
from ..leads.constants import LeadStatus, LeadType


class MobileProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: str
    phone: str | None = None
    email: str | None = None
    firstName: str | None = None
    lastName: str | None = None
    avatarUrl: str | None = None
    childBirthDate: date | None = None

    @classmethod
    def from_user(cls, user) -> 'MobileProfileResponse':
        return cls(
            id=user.id,
            phone=user.phone,
            email=user.email,
            firstName=user.first_name,
            lastName=user.last_name,
            avatarUrl=user.avatar_url,
            childBirthDate=user.child_birth_date,
        )


class MobileProfileUpdateRequest(BaseModel):
    firstName: str | None = None
    lastName: str | None = None
    email: EmailStr | None = None
    childBirthDate: date | None = None

    @field_validator('firstName')
    @classmethod
    def validate_first_name(cls, v: str | None) -> str | None:
        if v is None:
            return v
        stripped = v.strip()
        if len(stripped) == 0:
            raise ValueError('First name must not be empty.')
        if len(stripped) > 50:
            raise ValueError('First name must be at most 50 characters.')
        return stripped

    @field_validator('lastName')
    @classmethod
    def validate_last_name(cls, v: str | None) -> str | None:
        if v is None:
            return v
        stripped = v.strip()
        if len(stripped) == 0:
            raise ValueError('Last name must not be empty.')
        if len(stripped) > 50:
            raise ValueError('Last name must be at most 50 characters.')
        return stripped

    @field_validator('email', mode='before')
    @classmethod
    def strip_email(cls, v: object) -> object:
        if isinstance(v, str):
            return v.strip()
        return v

    @field_validator('childBirthDate')
    @classmethod
    def validate_child_birth_date(cls, v: date | None) -> date | None:
        if v is None:
            return v
        today = date.today()
        if v > today:
            raise ValueError('Child birth date must not be in the future.')
        from datetime import timedelta
        eighteen_years_ago = today.replace(year=today.year - 18)
        if v < eighteen_years_ago:
            raise ValueError('Child birth date must be within the last 18 years.')
        return v


class MobileAvatarUploadResponse(BaseModel):
    avatarUrl: str


class MobileProfileRequestListResponse(BaseModel):
    items: list['MobileProfileRequestItem']
    total: int
    limit: int
    offset: int


class MobileProfileRequestItem(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: str
    type: LeadType
    status: LeadStatus
    createdAt: datetime
    requestedDate: date | None = None
    guestCount: int | None = None
    notes: str | None = None
    branch: MobileRequestHistoryBranchSummary | None = None
    package: MobileRequestHistoryPackageSummary | None = None

    @field_serializer('createdAt')
    def serialize_created_at(self, value: datetime) -> str:
        created_at = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
        return created_at.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')
