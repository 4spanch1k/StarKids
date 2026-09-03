from fastapi import APIRouter, Depends, Request, Response

from ...core.exceptions.schemas import ErrorResponse
from ..mobile_auth.dependencies import (
    AuthenticatedMobileContext,
    get_current_mobile_auth_context,
)
from .dependencies import get_mobile_payment_service
from .schemas import (
    FreedomPaymentInitRequest,
    FreedomPaymentInitResponse,
    IssuedTicketResponse,
    IssuedTicketsResponse,
    IssuedTicketQrResponse,
    MobilePaymentStatusResponse,
    PurchasedTicketsResponse,
)
from .service import MobilePaymentService

mobile_router = APIRouter()
public_router = APIRouter()


@mobile_router.post(
    '/payments/freedom/init',
    response_model=FreedomPaymentInitResponse,
    responses={
        401: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
        503: {'model': ErrorResponse},
    },
)
def init_freedom_payment(
    payload: FreedomPaymentInitRequest,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: MobilePaymentService = Depends(get_mobile_payment_service),
) -> FreedomPaymentInitResponse:
    return service.init_freedom_ticket_payment(
        user=auth_context.user,
        payload=payload,
    )


@mobile_router.get(
    '/payments/{payment_id}',
    response_model=MobilePaymentStatusResponse,
    responses={
        401: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_payment_status(
    payment_id: str,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: MobilePaymentService = Depends(get_mobile_payment_service),
) -> MobilePaymentStatusResponse:
    return service.get_payment_status(
        payment_id=payment_id,
        mobile_user_id=auth_context.user.id,
    )


@mobile_router.get(
    '/tickets/purchases',
    response_model=PurchasedTicketsResponse,
    responses={401: {'model': ErrorResponse}},
)
def list_paid_tickets(
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: MobilePaymentService = Depends(get_mobile_payment_service),
) -> PurchasedTicketsResponse:
    return service.list_paid_tickets(auth_context.user.id)


@mobile_router.get(
    '/tickets',
    response_model=IssuedTicketsResponse,
    responses={401: {'model': ErrorResponse}},
)
def list_issued_tickets(
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: MobilePaymentService = Depends(get_mobile_payment_service),
) -> IssuedTicketsResponse:
    return service.list_issued_tickets(auth_context.user.id)


@mobile_router.get(
    '/tickets/{ticket_id}',
    response_model=IssuedTicketResponse,
    responses={401: {'model': ErrorResponse}, 404: {'model': ErrorResponse}},
)
def get_issued_ticket(
    ticket_id: str,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: MobilePaymentService = Depends(get_mobile_payment_service),
) -> IssuedTicketResponse:
    return service.get_issued_ticket(
        ticket_id=ticket_id,
        mobile_user_id=auth_context.user.id,
    )


@mobile_router.get(
    '/tickets/{ticket_id}/qr',
    response_model=IssuedTicketQrResponse,
    responses={401: {'model': ErrorResponse}, 404: {'model': ErrorResponse}},
)
def get_issued_ticket_qr(
    ticket_id: str,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: MobilePaymentService = Depends(get_mobile_payment_service),
) -> IssuedTicketQrResponse:
    return service.get_issued_ticket_qr(
        ticket_id=ticket_id,
        mobile_user_id=auth_context.user.id,
    )


@public_router.post('/payments/freedom/result')
async def handle_freedompay_result(
    request: Request,
    service: MobilePaymentService = Depends(get_mobile_payment_service),
) -> Response:
    payload = await _read_gateway_payload(request)
    result = service.handle_freedompay_result(payload)
    return Response(content=result.xml, media_type='application/xml')


async def _read_gateway_payload(request: Request) -> dict[str, str]:
    content_type = request.headers.get('content-type', '').lower()
    if 'application/json' in content_type:
        raw_payload = await request.json()
        if not isinstance(raw_payload, dict):
            return {}
        return {str(key): str(value) for key, value in raw_payload.items()}

    form = await request.form()
    return {str(key): str(value) for key, value in form.items()}
