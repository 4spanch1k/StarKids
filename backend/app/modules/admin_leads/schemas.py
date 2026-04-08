from datetime import date, datetime, timezone
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_serializer


LeadInboxStatus = Literal['new', 'in_progress', 'closed']
LeadInboxType = Literal['birthday_request']


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


class AdminLeadBaseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    type: LeadInboxType = 'birthday_request'
    status: LeadInboxStatus
    source: str
    customerName: str
    phone: str
    guestCount: int | None = None
    requestedDate: date | None = None
    createdAt: datetime
    branch: AdminLeadBranchSummary
    package: AdminLeadPackageSummary | None = None

    @field_serializer('createdAt')
    def serialize_created_at(self, value: datetime) -> str:
        created_at = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
        return created_at.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')


class AdminLeadListResponse(BaseModel):
    items: list[AdminLeadBaseResponse]
    total: int


class AdminLeadDetailResponse(AdminLeadBaseResponse):
    notes: str | None = None
    contactMethod: str


class AdminLeadStatusUpdateRequest(BaseModel):
    status: LeadInboxStatus
