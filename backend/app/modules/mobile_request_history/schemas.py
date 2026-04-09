from datetime import date, datetime, timezone

from pydantic import BaseModel, ConfigDict, field_serializer

from ..leads.constants import LeadStatus, LeadType

RequestHistoryType = LeadType
RequestHistoryStatus = LeadStatus


class MobileRequestHistoryBranchSummary(BaseModel):
    id: str
    name: str
    shortLabel: str


class MobileRequestHistoryPackageSummary(BaseModel):
    id: str
    name: str


class MobileRequestHistoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    type: RequestHistoryType
    status: RequestHistoryStatus
    createdAt: datetime
    requestedDate: date | None = None
    guestCount: int | None = None
    notes: str | None = None
    branch: MobileRequestHistoryBranchSummary | None = None
    package: MobileRequestHistoryPackageSummary | None = None

    @field_serializer('createdAt')
    def serialize_created_at(self, value: datetime) -> str:
        created_at = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
        return created_at.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')


class MobileRequestHistoryListResponse(BaseModel):
    items: list[MobileRequestHistoryItem]
    total: int
