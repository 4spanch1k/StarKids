from fastapi import APIRouter

from .schemas import BranchSummary
from .service import BranchService

router = APIRouter()
service = BranchService()


@router.get('/branches', response_model=list[BranchSummary])
def list_branches() -> list[BranchSummary]:
    return service.list_branches()

