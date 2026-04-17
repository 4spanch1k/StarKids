from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


PHONE_PATTERN = r'^[0-9+\-\s()]{8,20}$'


class BirthdayRequestCreate(BaseModel):
    branch_id: str = Field(min_length=1, max_length=120)
    birthday_package_id: str | None = Field(default=None, min_length=1, max_length=32)
    customer_name: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=8, max_length=20, pattern=PHONE_PATTERN)
    child_name: str | None = Field(default=None, min_length=2, max_length=120)
    child_age: int | None = Field(default=None, ge=1, le=18)
    guest_count: int | None = Field(default=None, ge=1, le=60)
    requested_date: date | None = None
    contact_method: Literal['phone', 'whatsapp'] = 'phone'
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator('requested_date')
    @classmethod
    def validate_requested_date(cls, value: date | None) -> date | None:
        if value is not None and value < date.today():
            raise ValueError('requested_date must be today or later.')
        return value


class BirthdayRequestCreatedResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    branch_id: str
    birthday_package_id: str | None = None
    status: str
    created_at: datetime
