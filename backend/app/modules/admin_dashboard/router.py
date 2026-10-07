from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ..admin_auth.dependencies import require_admin_roles
from .repository import AdminDashboardRepository
from .schemas import OwnerDashboardPeriod, OwnerDashboardResponse
from .service import AdminDashboardService


router = APIRouter(dependencies=[Depends(require_admin_roles('super_admin'))])


def get_admin_dashboard_service(
    session: Session = Depends(get_db_session),
) -> AdminDashboardService:
    return AdminDashboardService(repository=AdminDashboardRepository(session))


@router.get(
    '/dashboard/owner',
    response_model=OwnerDashboardResponse,
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}},
)
def get_owner_dashboard(
    period: OwnerDashboardPeriod = Query(default=OwnerDashboardPeriod.TODAY),
    service: AdminDashboardService = Depends(get_admin_dashboard_service),
) -> OwnerDashboardResponse:
    return service.get_owner_dashboard(period)
