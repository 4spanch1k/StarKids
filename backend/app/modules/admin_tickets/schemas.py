from datetime import UTC, date, datetime

from typing import Literal

from pydantic import BaseModel, Field, field_serializer


class AdminTicketRedeemRequest(BaseModel):
    qrPayload: str = Field(min_length=1, max_length=512)
    branchId: str = Field(min_length=1, max_length=32)


ManualRedemptionReason = Literal[
    'customer_device_unavailable',
    'qr_unavailable',
    'support_override',
]


class AdminManualTicketRedeemRequest(BaseModel):
    ticketId: str = Field(min_length=1, max_length=32)
    branchId: str = Field(min_length=1, max_length=32)
    reason: ManualRedemptionReason


class AdminTicketRedemptionResponse(BaseModel):
    outcome: str
    ticketId: str
    ticketNumber: str
    title: str
    branchId: str
    branchName: str
    visitDate: date | None = None
    status: str
    redeemedAt: datetime | None = None
    visitId: str | None = None

    @field_serializer('redeemedAt')
    def serialize_redeemed_at(self, value: datetime | None) -> str | None:
        if value is None:
            return None
        normalized = value if value.tzinfo is not None else value.replace(tzinfo=UTC)
        return normalized.astimezone(UTC).isoformat().replace('+00:00', 'Z')


class AdminTicketLookupRequest(BaseModel):
    query: str = Field(min_length=1, max_length=128)


class AdminTicketLookupTicket(BaseModel):
    ticketId: str
    ticketNumber: str
    title: str
    status: str
    visitDate: date | None = None
    redeemedAt: datetime | None = None
    visitId: str | None = None
    redemptionSource: str | None = None
    redemptionReason: str | None = None

    @field_serializer('redeemedAt')
    def serialize_redeemed_at(self, value: datetime | None) -> str | None:
        if value is None:
            return None
        normalized = value if value.tzinfo is not None else value.replace(tzinfo=UTC)
        return normalized.astimezone(UTC).isoformat().replace('+00:00', 'Z')


class AdminTicketLookupOrder(BaseModel):
    paymentId: str
    localOrderId: str
    phone: str | None = None
    branchId: str
    branchName: str
    visitDate: date | None = None
    amountTenge: int
    status: str
    tickets: list[AdminTicketLookupTicket] = Field(default_factory=list)


class AdminTicketLookupResponse(BaseModel):
    items: list[AdminTicketLookupOrder] = Field(default_factory=list)
