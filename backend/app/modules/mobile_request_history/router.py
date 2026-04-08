from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.repositories.mobile_request_history_repository import MobileRequestHistoryRepository
from ..mobile_auth.dependencies import get_current_mobile_user
from ..mobile_auth.schemas import MobileCurrentUserResponse
from .schemas import MobileRequestHistoryListResponse
from .service import MobileRequestHistoryService

router = APIRouter()


@router.get(
    '/me/requests',
    response_model=MobileRequestHistoryListResponse,
)
def list_mobile_request_history(
    current_mobile_user: MobileCurrentUserResponse = Depends(get_current_mobile_user),
    session: Session = Depends(get_db_session),
) -> MobileRequestHistoryListResponse:
    service = MobileRequestHistoryService(
        repository=MobileRequestHistoryRepository(session),
    )
    return service.list_for_mobile_user(current_mobile_user.id)
