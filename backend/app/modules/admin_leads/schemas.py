from datetime import date, datetime, timezone

from pydantic import BaseModel, ConfigDict, Field, field_serializer

from ..admin_dashboard.schemas import OwnerDashboardPeriod
from ..leads.constants import LeadStatus, LeadType

LeadInboxStatus = LeadStatus
LeadInboxType = LeadType


class AdminLeadBranchSummary(BaseModel):
    id: str
    name: str
    shortLabel: str


class AdminLeadPackageSummary(BaseModel):
    id: str
    name: str


class AdminLeadListQuery(BaseModel):
    branchId: str | None = Field(default=None, min_length=1, max_length=32)
    status: LeadInboxStatus | None = None
    createdFrom: date | None = None
    createdTo: date | None = None
    awaitingContact: bool = False
    sort: str = Field(default='newest', pattern='^(newest|oldest_uncontacted)$')


class AdminLeadBaseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    type: LeadInboxType = 'birthday_request'
    summary: str
    status: LeadInboxStatus
    source: str
    customerName: str
    phone: str
    guestCount: int | None = None
    requestedDate: date | None = None
    createdAt: datetime
    waitingForContactMinutes: int | None = None
    firstContactMinutes: int | None = None
    branch: AdminLeadBranchSummary | None = None
    package: AdminLeadPackageSummary | None = None

    @field_serializer('createdAt')
    def serialize_created_at(self, value: datetime) -> str:
        created_at = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
        return created_at.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')


class AdminLeadListResponse(BaseModel):
    items: list[AdminLeadBaseResponse]
    total: int


class AdminLeadDetailResponse(AdminLeadBaseResponse):
    email: str | None = None
    notes: str | None = None
    contactMethod: str


class AdminBirthdayLeadDetailResponse(BaseModel):
    id: str
    status: LeadInboxStatus
    source: str
    customerName: str
    phone: str
    contactMethod: str
    childId: str | None = None
    childName: str | None = None
    childBirthDate: date | None = None
    requestedDate: date | None = None
    guestCount: int | None = None
    branch: AdminLeadBranchSummary | None = None
    package: AdminLeadPackageSummary | None = None
    packageNameSnapshot: str | None = None
    packagePriceSnapshot: int | None = None
    agreedAmountTenge: int | None = None
    lostReason: str | None = None
    comment: str | None = None
    adminNote: str | None = None
    createdAt: datetime
    waitingForContactMinutes: int | None = None
    firstContactMinutes: int | None = None
    updatedAt: datetime
    contactedAt: datetime | None = None
    qualifiedAt: datetime | None = None
    bookedAt: datetime | None = None
    completedAt: datetime | None = None
    lostAt: datetime | None = None
    closedAt: datetime | None = None


class AdminLeadStatusUpdateRequest(BaseModel):
    status: LeadInboxStatus
    adminNote: str | None = Field(default=None, max_length=2000)
    agreedAmountTenge: int | None = Field(default=None, ge=0)
    lostReason: str | None = Field(default=None, min_length=1, max_length=32)


class AdminBirthdayOperationsSummaryResponse(BaseModel):
    period: OwnerDashboardPeriod
    periodStart: datetime
    periodEnd: datetime
    timezone: str
    newAwaitingContact: int
    oldestWaitingMinutes: int | None
    leadsCreated: int
    contactedFromCreatedLeads: int
    medianFirstContactMinutes: int | None
    p90FirstContactMinutes: int | None
