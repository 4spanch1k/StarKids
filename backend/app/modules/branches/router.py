from fastapi import APIRouter, Depends, Path
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.branch_repository import BranchRepository
from .schemas import BranchDetail, BranchSummary
from .service import BranchService

router = APIRouter()


@router.get(
    '/branches',
    response_model=list[BranchSummary],
    responses={422: {'model': ErrorResponse}},
)
def list_branches(
    session: Session = Depends(get_db_session),
) -> list[BranchSummary]:
    service = BranchService(repository=BranchRepository(session))
    return service.list_branches()


@router.get(
    '/branches/{branch_id_or_slug}',
    response_model=BranchDetail,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_branch(
    branch_id_or_slug: str = Path(min_length=2, max_length=120),
    session: Session = Depends(get_db_session),
) -> BranchDetail:
    service = BranchService(repository=BranchRepository(session))
    return service.get_branch(branch_id_or_slug)
