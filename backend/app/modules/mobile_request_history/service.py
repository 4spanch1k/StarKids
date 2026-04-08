from ...db.repositories.mobile_request_history_repository import (
    MobileRequestHistoryRecord,
    MobileRequestHistoryRepository,
)
from .schemas import (
    MobileRequestHistoryBranchSummary,
    MobileRequestHistoryItem,
    MobileRequestHistoryListResponse,
    MobileRequestHistoryPackageSummary,
)


class MobileRequestHistoryService:
    def __init__(
        self,
        *,
        repository: MobileRequestHistoryRepository | None = None,
    ) -> None:
        self.repository = repository or MobileRequestHistoryRepository()

    def list_for_mobile_user(self, mobile_user_id: str) -> MobileRequestHistoryListResponse:
        records = self.repository.list_for_mobile_user(mobile_user_id)
        items = [self._serialize_record(record) for record in records]
        return MobileRequestHistoryListResponse(
            items=items,
            total=len(items),
        )

    def _serialize_record(self, record: MobileRequestHistoryRecord) -> MobileRequestHistoryItem:
        return MobileRequestHistoryItem(
            id=record.id,
            type=record.type,
            status=record.status,
            createdAt=record.created_at,
            requestedDate=record.requested_date,
            guestCount=record.guest_count,
            notes=record.notes,
            branch=(
                MobileRequestHistoryBranchSummary(
                    id=record.branch_id,
                    name=record.branch_name,
                    shortLabel=record.branch_short_label,
                )
                if record.branch_id is not None
                and record.branch_name is not None
                and record.branch_short_label is not None
                else None
            ),
            package=(
                MobileRequestHistoryPackageSummary(
                    id=record.birthday_package_id,
                    name=record.birthday_package_name,
                )
                if record.birthday_package_id is not None
                and record.birthday_package_name is not None
                else None
            ),
        )
