from __future__ import annotations

from datetime import date
from enum import Enum

from pydantic import BaseModel, ConfigDict, field_validator


class ChildGender(str, Enum):
    male = 'male'
    female = 'female'


class ChildResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: str
    name: str
    birthDate: date
    gender: ChildGender

    @classmethod
    def from_model(cls, child) -> 'ChildResponse':
        return cls(
            id=child.id,
            name=child.name,
            birthDate=child.birth_date,
            gender=ChildGender(child.gender),
        )


class ChildListResponse(BaseModel):
    items: list[ChildResponse]


class ChildCreateRequest(BaseModel):
    name: str
    birthDate: date
    gender: ChildGender

    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError('Child name must not be empty.')
        if len(stripped) > 100:
            raise ValueError('Child name must be at most 100 characters.')
        return stripped

    @field_validator('birthDate')
    @classmethod
    def validate_birth_date(cls, v: date) -> date:
        today = date.today()
        if v > today:
            raise ValueError('Birth date must not be in the future.')
        eighteen_years_ago = today.replace(year=today.year - 18)
        if v < eighteen_years_ago:
            raise ValueError('Birth date must be within the last 18 years.')
        return v


class ChildUpdateRequest(BaseModel):
    name: str | None = None
    birthDate: date | None = None
    gender: ChildGender | None = None

    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str | None) -> str | None:
        if v is None:
            return v
        stripped = v.strip()
        if not stripped:
            raise ValueError('Child name must not be empty.')
        if len(stripped) > 100:
            raise ValueError('Child name must be at most 100 characters.')
        return stripped

    @field_validator('birthDate')
    @classmethod
    def validate_birth_date(cls, v: date | None) -> date | None:
        if v is None:
            return v
        today = date.today()
        if v > today:
            raise ValueError('Birth date must not be in the future.')
        eighteen_years_ago = today.replace(year=today.year - 18)
        if v < eighteen_years_ago:
            raise ValueError('Birth date must be within the last 18 years.')
        return v
