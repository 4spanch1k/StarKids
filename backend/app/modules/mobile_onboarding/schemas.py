from __future__ import annotations

from datetime import date, datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator

from ..mobile_children.schemas import ChildResponse
from ..mobile_profile.schemas import MobileProfileResponse


class OnboardingGender(str, Enum):
    male = 'male'
    female = 'female'
    unspecified = 'unspecified'


class OnboardingChildInput(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    birthDate: date
    gender: OnboardingGender = OnboardingGender.unspecified

    @field_validator('name')
    @classmethod
    def validate_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError('Child name must not be empty.')
        return value

    @field_validator('birthDate')
    @classmethod
    def validate_birth_date(cls, value: date) -> date:
        if value > date.today():
            raise ValueError('Birth date must not be in the future.')
        if value.year < 1900:
            raise ValueError('Birth date is not valid.')
        return value


class OnboardingCompleteRequest(BaseModel):
    firstName: str = Field(min_length=1, max_length=50)
    children: list[OnboardingChildInput] = Field(default_factory=list, max_length=20)
    privacyConsentAccepted: bool
    privacyConsentVersion: str = Field(min_length=1, max_length=64)

    @field_validator('firstName')
    @classmethod
    def validate_first_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError('Parent name must not be empty.')
        return value


class OnboardingCompleteResponse(BaseModel):
    onboardingCompleted: bool
    onboardingCompletedAt: datetime | None = None
    privacyConsentAt: datetime | None = None
    privacyConsentVersion: str | None = None
    profile: MobileProfileResponse
    children: list[ChildResponse]
