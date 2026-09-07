from fastapi import APIRouter, Depends, Query

from ...core.exceptions.schemas import ErrorResponse
from ..admin_auth.dependencies import require_admin_roles
from ..admin_auth.schemas import AdminCurrentUserResponse
from .dependencies import get_ticket_redemption_service
from .schemas import (
    AdminTicketLookupResponse,
    AdminTicketRedeemRequest,
    AdminManualTicketRedeemRequest,
    AdminTicketRedemptionResponse,
)
from .service import TicketRedemptionService


router = APIRouter()


@router.post(
    '/tickets/redeem',
    response_model=AdminTicketRedemptionResponse,
    responses={
        400: {'model': ErrorResponse},
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        409: {'model': ErrorResponse},
    },
)
def redeem_ticket(
    payload: AdminTicketRedeemRequest,
    current_admin_user: AdminCurrentUserResponse = Depends(
        require_admin_roles('super_admin', 'operator')
    ),
    service: TicketRedemptionService = Depends(get_ticket_redemption_service),
) -> AdminTicketRedemptionResponse:
    return service.redeem(
        qr_payload=payload.qrPayload,
        branch_id=payload.branchId,
        admin_user=current_admin_user,
    )


@router.post(
    '/tickets/redeem-manual',
    response_model=AdminTicketRedemptionResponse,
    responses={400: {'model': ErrorResponse}, 401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}, 404: {'model': ErrorResponse}, 409: {'model': ErrorResponse}},
)
def redeem_ticket_manually(
    payload: AdminManualTicketRedeemRequest,
    current_admin_user: AdminCurrentUserResponse = Depends(
        require_admin_roles('super_admin', 'operator')
    ),
    service: TicketRedemptionService = Depends(get_ticket_redemption_service),
) -> AdminTicketRedemptionResponse:
    return service.redeem_manual(
        ticket_id=payload.ticketId,
        branch_id=payload.branchId,
        reason=payload.reason,
        admin_user=current_admin_user,
    )


@router.get(
    '/tickets/lookup',
    response_model=AdminTicketLookupResponse,
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}},
)
def lookup_tickets(
    query: str = Query(min_length=1, max_length=128),
    current_admin_user: AdminCurrentUserResponse = Depends(
        require_admin_roles('super_admin', 'operator')
    ),
    service: TicketRedemptionService = Depends(get_ticket_redemption_service),
) -> AdminTicketLookupResponse:
    return service.lookup(query, current_admin_user)
