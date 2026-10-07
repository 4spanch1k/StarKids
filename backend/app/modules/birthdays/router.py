from fastapi import APIRouter, Depends, Path, Query
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.branch_repository import BranchRepository
from .schemas import BirthdayPackageDetail, BirthdayPackageSummary
from .service import BirthdayService

router = APIRouter()


@router.get(
    '/birthday-packages',
    response_model=list[BirthdayPackageSummary],
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def list_birthday_packages(
    branch_id: str | None = Query(default=None, min_length=1, max_length=120),
    session: Session = Depends(get_db_session),
) -> list[BirthdayPackageSummary]:
    service = BirthdayService(
        repository=BirthdayPackageRepository(session),
        branch_repository=BranchRepository(session),
    )
    return service.list_packages(branch_id=branch_id)


@router.get(
    '/birthday-packages/{package_id}',
    response_model=BirthdayPackageDetail,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_birthday_package(
    package_id: str = Path(min_length=1, max_length=32),
    session: Session = Depends(get_db_session),
) -> BirthdayPackageDetail:
    service = BirthdayService(
        repository=BirthdayPackageRepository(session),
        branch_repository=BranchRepository(session),
    )
    return service.get_package(package_id)
