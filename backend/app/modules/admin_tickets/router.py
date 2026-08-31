from fastapi import APIRouter, Depends

from ...core.exceptions.schemas import ErrorResponse
from ..admin_auth.dependencies import require_admin_roles
from ..admin_auth.schemas import AdminCurrentUserResponse
from .dependencies import get_ticket_redemption_service
from .schemas import AdminTicketRedeemRequest, AdminTicketRedemptionResponse
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
