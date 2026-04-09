from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.branch_repository import BranchRepository
from ..admin_auth.dependencies import require_admin_roles
from .schemas import (
    AdminBirthdayPackageCreateRequest,
    AdminBirthdayPackageDetailResponse,
    AdminBirthdayPackageListQuery,
    AdminBirthdayPackageSummaryResponse,
    AdminBirthdayPackageUpdateRequest,
)
from .service import (
    AdminBirthdayPackageService,
    BIRTHDAY_PACKAGE_ADMIN_ALLOWED_ROLES,
)

router = APIRouter(
    dependencies=[Depends(require_admin_roles(*BIRTHDAY_PACKAGE_ADMIN_ALLOWED_ROLES))]
)


def get_admin_birthday_package_service(
    session: Session = Depends(get_db_session),
) -> AdminBirthdayPackageService:
    return AdminBirthdayPackageService(
        repository=BirthdayPackageRepository(session),
        branch_repository=BranchRepository(session),
    )


@router.get(
    '/birthday-packages',
    response_model=list[AdminBirthdayPackageSummaryResponse],
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def list_admin_birthday_packages(
    query: Annotated[AdminBirthdayPackageListQuery, Depends()],
    service: AdminBirthdayPackageService = Depends(get_admin_birthday_package_service),
) -> list[AdminBirthdayPackageSummaryResponse]:
    return service.list_packages(query)


@router.get(
    '/birthday-packages/{package_id}',
    response_model=AdminBirthdayPackageDetailResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_birthday_package(
    package_id: str,
    service: AdminBirthdayPackageService = Depends(get_admin_birthday_package_service),
) -> AdminBirthdayPackageDetailResponse:
    return service.get_package(package_id)


@router.post(
    '/birthday-packages',
    response_model=AdminBirthdayPackageDetailResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def create_admin_birthday_package(
    payload: AdminBirthdayPackageCreateRequest,
    service: AdminBirthdayPackageService = Depends(get_admin_birthday_package_service),
) -> AdminBirthdayPackageDetailResponse:
    return service.create_package(payload)


@router.patch(
    '/birthday-packages/{package_id}',
    response_model=AdminBirthdayPackageDetailResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_birthday_package(
    package_id: str,
    payload: AdminBirthdayPackageUpdateRequest,
    service: AdminBirthdayPackageService = Depends(get_admin_birthday_package_service),
) -> AdminBirthdayPackageDetailResponse:
    return service.update_package(package_id, payload)
