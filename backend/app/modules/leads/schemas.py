from datetime import date, datetime, timezone

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_serializer,
    field_validator,
)

from .constants import LeadStatus, LeadType

PHONE_PATTERN = r'^\+?[0-9()\- ]{10,20}$'


class ContactLeadCreate(BaseModel):
    name: str
    phone: str
    message: str | None = None
    email: EmailStr | None = None


class BirthdayLeadCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=10, max_length=20, pattern=PHONE_PATTERN)
    branchId: str = Field(min_length=1, max_length=32)
    preferredDate: date | None = None
    guestCount: int | None = Field(default=None, ge=1, le=60)
    comment: str | None = Field(default=None, max_length=1000)
    packageId: str | None = Field(default=None, min_length=1, max_length=32)

    @field_validator('preferredDate')
    @classmethod
    def validate_preferred_date(cls, value: date | None) -> date | None:
        if value is not None and value < date.today():
            raise ValueError('preferredDate must be today or later.')
        return value


class LeadCreatedResponse(BaseModel):
    id: str
    type: LeadType
    status: LeadStatus


class BirthdayLeadSubmittedResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    requestId: str
    submittedAt: datetime
    nextStep: str

    @field_serializer('submittedAt')
    def serialize_submitted_at(self, value: datetime) -> str:
        submitted_at = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
        return submitted_at.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')


class BirthdayLeadValidationErrorResponse(BaseModel):
    message: str
    errors: dict[str, list[str]]


class BirthdayLeadGenericErrorResponse(BaseModel):
    message: str
