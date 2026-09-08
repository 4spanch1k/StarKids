from __future__ import annotations

from datetime import UTC, date, datetime

from pydantic import BaseModel, Field, field_serializer


def _utc_iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    normalized = value if value.tzinfo is not None else value.replace(tzinfo=UTC)
    return normalized.astimezone(UTC).isoformat().replace('+00:00', 'Z')


class AdminCustomerListQuery(BaseModel):
    search: str | None = Field(default=None, max_length=120)
    page: int = Field(default=1, ge=1, le=100_000)
    pageSize: int = Field(default=25, ge=1, le=100)


class AdminCustomerListItem(BaseModel):
    id: str
    firstName: str | None = None
    lastName: str | None = None
    phone: str | None = None
    email: str | None = None
    childrenCount: int
    visitsCount: int
    lastVisitAt: datetime | None = None
    ticketCashSpendTenge: int
    bonusBalance: int
    createdAt: datetime

    @field_serializer('lastVisitAt', 'createdAt')
    def serialize_datetime(self, value: datetime | None) -> str | None:
        return _utc_iso(value)


class AdminCustomerListResponse(BaseModel):
    items: list[AdminCustomerListItem]
    total: int
    page: int
    pageSize: int


class AdminCustomerResponse(BaseModel):
    id: str
    firstName: str | None = None
    lastName: str | None = None
    phone: str | None = None
    email: str | None = None
    isActive: bool
    createdAt: datetime

    @field_serializer('createdAt')
    def serialize_created_at(self, value: datetime) -> str:
        return _utc_iso(value) or ''


class AdminCustomerChildResponse(BaseModel):
    id: str
    name: str
    birthDate: date
    gender: str
    createdAt: datetime

    @field_serializer('createdAt')
    def serialize_created_at(self, value: datetime) -> str:
        return _utc_iso(value) or ''


class AdminCustomerBranchResponse(BaseModel):
    id: str
    name: str
    shortLabel: str


class AdminCustomerVisitResponse(BaseModel):
    id: str
    branch: AdminCustomerBranchResponse | None = None
    status: str
    startedAt: datetime
    endedAt: datetime | None = None

    @field_serializer('startedAt', 'endedAt')
    def serialize_datetime(self, value: datetime | None) -> str | None:
        return _utc_iso(value)


class AdminCustomerTicketPurchaseResponse(BaseModel):
    id: str
    localOrderId: str
    branch: AdminCustomerBranchResponse | None = None
    paidAt: datetime | None = None
    visitDate: date | None = None
    quantity: int
    grossAmountTenge: int
    bonusAmount: int
    cashAmountTenge: int
    currency: str
    status: str

    @field_serializer('paidAt')
    def serialize_paid_at(self, value: datetime | None) -> str | None:
        return _utc_iso(value)


class AdminCustomerLoyaltyResponse(BaseModel):
    balance: int = 0
    lifetimeEarned: int = 0
    lifetimeSpent: int = 0


class AdminCustomerBirthdayLeadResponse(BaseModel):
    id: str
    childName: str | None = None
    childBirthDate: date | None = None
    desiredDate: date | None = None
    branch: AdminCustomerBranchResponse | None = None
    packageName: str | None = None
    status: str
    agreedAmountTenge: int | None = None
    lostReason: str | None = None
    createdAt: datetime
    contactedAt: datetime | None = None
    qualifiedAt: datetime | None = None
    bookedAt: datetime | None = None
    completedAt: datetime | None = None
    lostAt: datetime | None = None

    @field_serializer('createdAt', 'contactedAt', 'qualifiedAt', 'bookedAt', 'completedAt', 'lostAt')
    def serialize_datetime(self, value: datetime | None) -> str | None:
        return _utc_iso(value)


class AdminCustomerMetricsResponse(BaseModel):
    childrenCount: int
    visitsCount: int
    firstVisitAt: datetime | None = None
    lastVisitAt: datetime | None = None
    ticketCashSpendTenge: int

    @field_serializer('firstVisitAt', 'lastVisitAt')
    def serialize_datetime(self, value: datetime | None) -> str | None:
        return _utc_iso(value)


class AdminCustomerDetailResponse(BaseModel):
    customer: AdminCustomerResponse
    metrics: AdminCustomerMetricsResponse
    loyalty: AdminCustomerLoyaltyResponse
    children: list[AdminCustomerChildResponse]
    recentVisits: list[AdminCustomerVisitResponse]
    recentTicketPurchases: list[AdminCustomerTicketPurchaseResponse]
    birthdayLeads: list[AdminCustomerBirthdayLeadResponse]
