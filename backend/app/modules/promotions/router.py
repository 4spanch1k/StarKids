from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.promotion_repository import PromotionRepository
from .schemas import PromotionSummary
from .service import PromotionsService

router = APIRouter()


@router.get(
    '/promotions',
    response_model=list[PromotionSummary],
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def list_promotions(
    branch_id: str | None = Query(default=None, min_length=1, max_length=32),
    session: Session = Depends(get_db_session),
) -> list[PromotionSummary]:
    service = PromotionsService(
        repository=PromotionRepository(session),
        branch_repository=BranchRepository(session),
    )
    return service.list_promotions(branch_id=branch_id)
