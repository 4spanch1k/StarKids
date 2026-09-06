from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

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
    branchId: str = Field(min_length=1, max_length=120)
    preferredDate: date | None = None
    guestCount: int | None = Field(default=None, ge=1, le=60)
    comment: str | None = Field(default=None, max_length=1000)
    packageId: str | None = Field(default=None, min_length=1, max_length=32)
    childId: str | None = Field(default=None, min_length=1, max_length=32)
    idempotencyKey: str | None = Field(default=None, min_length=8, max_length=128)

    @field_validator('preferredDate')
    @classmethod
    def validate_preferred_date(cls, value: date | None) -> date | None:
        if value is not None and value < datetime.now(ZoneInfo('Asia/Almaty')).date():
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


class BirthdayLeadResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    status: LeadStatus
    childId: str | None = None
    childName: str | None = None
    childBirthDate: date | None = None
    branchId: str
    packageId: str | None = None
    packageName: str | None = None
    requestedDate: date | None = None
    guestCount: int | None = None
    comment: str | None = None
    createdAt: datetime
    updatedAt: datetime
    contactedAt: datetime | None = None
    closedAt: datetime | None = None


class BirthdayLeadListResponse(BaseModel):
    items: list[BirthdayLeadResponse]
    total: int


class BirthdayLeadValidationErrorResponse(BaseModel):
    message: str
    errors: dict[str, list[str]]


class BirthdayLeadGenericErrorResponse(BaseModel):
    message: str
