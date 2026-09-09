from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ..admin_auth.dependencies import require_admin_roles
from .schemas import AdminStaffBranchUpdateRequest, AdminStaffListResponse, AdminStaffResponse
from .service import AdminStaffService


router = APIRouter(dependencies=[Depends(require_admin_roles('super_admin'))])


def get_admin_staff_service(session: Session = Depends(get_db_session)) -> AdminStaffService:
    return AdminStaffService(session)


@router.get(
    '/staff',
    response_model=AdminStaffListResponse,
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}},
)
def list_staff(
    service: AdminStaffService = Depends(get_admin_staff_service),
) -> AdminStaffListResponse:
    return service.list_staff()


@router.patch(
    '/staff/{admin_user_id}/branch',
    response_model=AdminStaffResponse,
    responses={
        400: {'model': ErrorResponse},
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def update_staff_branch(
    admin_user_id: str,
    payload: AdminStaffBranchUpdateRequest,
    service: AdminStaffService = Depends(get_admin_staff_service),
) -> AdminStaffResponse:
    return service.update_branch(admin_user_id, payload)
