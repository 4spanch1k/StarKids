from datetime import date, datetime, timezone

from pydantic import BaseModel, Field, field_serializer


class FreedomPaymentTicketItemRequest(BaseModel):
    ticketItemId: str = Field(min_length=1, max_length=32)
    quantity: int = Field(ge=1, le=20)


class FreedomPaymentInitRequest(BaseModel):
    ticketItems: list[FreedomPaymentTicketItemRequest] = Field(min_length=1, max_length=20)
    visitDate: date | None = None


class FreedomPaymentInitResponse(BaseModel):
    paymentId: str
    localOrderId: str
    externalPaymentId: str | None = None
    paymentUrl: str
    status: str


class MobilePaymentStatusResponse(BaseModel):
    paymentId: str
    localOrderId: str
    externalPaymentId: str | None = None
    amountTenge: int
    currency: str
    status: str
    failureReason: str | None = None
    paidAt: datetime | None = None

    @field_serializer('paidAt')
    def serialize_paid_at(self, value: datetime | None) -> str | None:
        return _serialize_datetime(value)


class PurchasedTicketLineItemResponse(BaseModel):
    ticketItemId: str
    title: str
    priceTenge: int
    quantity: int


class PurchasedTicketResponse(BaseModel):
    paymentId: str
    localOrderId: str
    branchId: str
    branchName: str
    visitDate: date | None = None
    amountTenge: int
    currency: str
    paidAt: datetime | None = None
    items: list[PurchasedTicketLineItemResponse] = Field(default_factory=list)

    @field_serializer('paidAt')
    def serialize_paid_at(self, value: datetime | None) -> str | None:
        return _serialize_datetime(value)


class PurchasedTicketsResponse(BaseModel):
    items: list[PurchasedTicketResponse] = Field(default_factory=list)
    total: int


def _serialize_datetime(value: datetime | None) -> str | None:
    if value is None:
        return None
    normalized = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
    return normalized.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')
