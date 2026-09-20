from datetime import UTC, date, datetime
from typing import Literal

from pydantic import BaseModel, Field, field_serializer


class PassPlanResponse(BaseModel):
    id: str
    name: str
    priceTenge: int
    visitLimit: int
    validityDays: int
    dailyLimit: int
    branchId: str | None = None
    isActive: bool


class PassPlanCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    priceTenge: int = Field(gt=0)
    visitLimit: int = Field(gt=0)
    validityDays: int = Field(gt=0)
    dailyLimit: int = Field(default=1, ge=1)
    branchId: str | None = Field(default=None, max_length=32)
    isActive: bool = True


class PassPlanUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    priceTenge: int | None = Field(default=None, gt=0)
    visitLimit: int | None = Field(default=None, gt=0)
    validityDays: int | None = Field(default=None, gt=0)
    dailyLimit: int | None = Field(default=None, ge=1)
    branchId: str | None = Field(default=None, max_length=32)
    isActive: bool | None = None


class PassQuoteRequest(BaseModel):
    childId: str = Field(min_length=1, max_length=32)
    passPlanId: str = Field(min_length=1, max_length=32)
    branchId: str = Field(min_length=1, max_length=32)


class PassQuoteResponse(BaseModel):
    passPlan: PassPlanResponse
    childId: str
    branchId: str
    amountTenge: int
    currency: str = 'KZT'


class PassInitRequest(PassQuoteRequest):
    idempotencyKey: str = Field(min_length=16, max_length=128)


class PassInitResponse(BaseModel):
    paymentId: str
    localOrderId: str
    externalPaymentId: str | None = None
    paymentUrl: str
    status: str
    amountTenge: int


class CustomerPassResponse(BaseModel):
    id: str
    childId: str
    childName: str
    passPlanId: str
    planName: str
    priceTenge: int
    visitLimit: int
    validityDays: int
    dailyLimit: int
    branchId: str | None = None
    activatedAt: datetime
    expiresAt: datetime
    remainingVisits: int
    status: str

    @field_serializer('activatedAt', 'expiresAt')
    def serialize_datetime(self, value: datetime) -> str:
        normalized = value if value.tzinfo else value.replace(tzinfo=UTC)
        return normalized.astimezone(UTC).isoformat().replace('+00:00', 'Z')


class CustomerPassListResponse(BaseModel):
    items: list[CustomerPassResponse] = Field(default_factory=list)
    total: int


class CustomerPassQrResponse(BaseModel):
    passId: str
    qrPayload: str
    version: str = 'v1'


class AdminPassRedemptionRequest(BaseModel):
    ticketId: str | None = None
    passId: str | None = None
    branchId: str = Field(min_length=1, max_length=32)
    reason: str | None = Field(default=None, max_length=64)


class AdminManualPassRedeemRequest(BaseModel):
    passId: str = Field(min_length=1, max_length=32)
    branchId: str = Field(min_length=1, max_length=32)
    reason: str = Field(min_length=1, max_length=64)


class GenericAdmissionRequest(BaseModel):
    qrPayload: str = Field(min_length=1, max_length=512)
    branchId: str = Field(min_length=1, max_length=32)


class GenericAdmissionResponse(BaseModel):
    kind: Literal['ticket', 'pass']
    outcome: str
    ticketId: str | None = None
    ticketNumber: str | None = None
    passId: str | None = None
    planName: str | None = None
    childId: str | None = None
    childName: str | None = None
    remainingVisits: int | None = None
    visitLimit: int | None = None
    status: str | None = None
    expiresAt: datetime | None = None
    branchId: str
    branchName: str
    visitId: str | None = None
    redeemedAt: datetime | None = None

    @field_serializer('expiresAt', 'redeemedAt')
    def serialize_datetime(self, value: datetime | None) -> str | None:
        if value is None:
            return None
        normalized = value if value.tzinfo else value.replace(tzinfo=UTC)
        return normalized.astimezone(UTC).isoformat().replace('+00:00', 'Z')
