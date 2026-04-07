from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.lead_inbox_repository import LeadInboxRepository
from ..admin_auth.dependencies import require_admin_roles
from .schemas import (
    AdminLeadDetailResponse,
    AdminLeadListQuery,
    AdminLeadListResponse,
    AdminLeadStatusUpdateRequest,
)
from .service import AdminLeadInboxService, LEAD_INBOX_ALLOWED_ROLES

router = APIRouter(
    dependencies=[Depends(require_admin_roles(*LEAD_INBOX_ALLOWED_ROLES))]
)


def get_admin_lead_inbox_service(
    session: Session = Depends(get_db_session),
) -> AdminLeadInboxService:
    return AdminLeadInboxService(
        repository=LeadInboxRepository(session),
    )


@router.get(
    '/leads',
    response_model=AdminLeadListResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def list_admin_leads(
    filters: Annotated[AdminLeadListQuery, Depends()],
    service: AdminLeadInboxService = Depends(get_admin_lead_inbox_service),
) -> AdminLeadListResponse:
    return service.list_leads(filters)


@router.get(
    '/leads/{lead_id}',
    response_model=AdminLeadDetailResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_lead(
    lead_id: str,
    service: AdminLeadInboxService = Depends(get_admin_lead_inbox_service),
) -> AdminLeadDetailResponse:
    return service.get_lead(lead_id)


@router.patch(
    '/leads/{lead_id}/status',
    response_model=AdminLeadDetailResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_lead_status(
    lead_id: str,
    payload: AdminLeadStatusUpdateRequest,
    service: AdminLeadInboxService = Depends(get_admin_lead_inbox_service),
) -> AdminLeadDetailResponse:
    return service.update_lead_status(lead_id, payload)
