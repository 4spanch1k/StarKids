from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ..admin_auth.dependencies import require_admin_roles
from .repository import AdminReconciliationRepository
from .schemas import ReconciliationResponse
from .service import AdminReconciliationService

router = APIRouter()


def get_reconciliation_service(
    session: Session = Depends(get_db_session),
) -> AdminReconciliationService:
    return AdminReconciliationService(repository=AdminReconciliationRepository(session))


@router.get(
    '/reconciliation',
    response_model=ReconciliationResponse,
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}},
)
def list_reconciliation_items(
    service: AdminReconciliationService = Depends(get_reconciliation_service),
    _admin=Depends(require_admin_roles('super_admin')),
) -> ReconciliationResponse:
    return service.list_items()
