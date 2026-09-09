from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.admin_customer_repository import AdminCustomerRepository
from ..admin_auth.dependencies import require_admin_roles
from .schemas import AdminCustomerDetailResponse, AdminCustomerListQuery, AdminCustomerListResponse
from .service import AdminCustomerService

router = APIRouter(dependencies=[Depends(require_admin_roles('super_admin'))])


def get_admin_customer_service(session: Session = Depends(get_db_session)) -> AdminCustomerService:
    return AdminCustomerService(repository=AdminCustomerRepository(session))


@router.get(
    '/customers',
    response_model=AdminCustomerListResponse,
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}},
)
def list_customers(
    query: Annotated[AdminCustomerListQuery, Depends()],
    service: AdminCustomerService = Depends(get_admin_customer_service),
) -> AdminCustomerListResponse:
    return service.list_customers(query)


@router.get(
    '/customers/{customer_id}',
    response_model=AdminCustomerDetailResponse,
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}, 404: {'model': ErrorResponse}},
)
def get_customer(
    customer_id: str,
    service: AdminCustomerService = Depends(get_admin_customer_service),
) -> AdminCustomerDetailResponse:
    return service.get_customer(customer_id)
