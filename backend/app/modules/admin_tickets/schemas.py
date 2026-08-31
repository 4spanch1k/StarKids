from datetime import UTC, date, datetime

from pydantic import BaseModel, Field, field_serializer


class AdminTicketRedeemRequest(BaseModel):
    qrPayload: str = Field(min_length=1, max_length=512)
    branchId: str = Field(min_length=1, max_length=32)


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

    @field_serializer('redeemedAt')
    def serialize_redeemed_at(self, value: datetime | None) -> str | None:
        if value is None:
            return None
        normalized = value if value.tzinfo is not None else value.replace(tzinfo=UTC)
        return normalized.astimezone(UTC).isoformat().replace('+00:00', 'Z')
