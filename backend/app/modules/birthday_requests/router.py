from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.birthday_request_repository import BirthdayRequestRepository
from ...db.repositories.branch_repository import BranchRepository
from .schemas import BirthdayRequestCreate, BirthdayRequestCreatedResponse
from .service import BirthdayRequestService

router = APIRouter()


@router.post(
    '/requests/birthday',
    response_model=BirthdayRequestCreatedResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def create_birthday_request(
    payload: BirthdayRequestCreate,
    session: Session = Depends(get_db_session),
) -> BirthdayRequestCreatedResponse:
    service = BirthdayRequestService(
        request_repository=BirthdayRequestRepository(session),
        branch_repository=BranchRepository(session),
        package_repository=BirthdayPackageRepository(session),
    )
    return service.create_request(payload)
