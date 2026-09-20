from fastapi import APIRouter, Depends

from ...core.exceptions.schemas import ErrorResponse
from ...core.exceptions.http import NotFoundException
from ...db.models.customer_pass import CustomerPass
from ..admin_auth.dependencies import require_admin_roles
from ..admin_auth.schemas import AdminCurrentUserResponse
from ..mobile_auth.dependencies import AuthenticatedMobileContext, get_current_mobile_auth_context
from ..mobile_payments.dependencies import get_mobile_payment_service
from ..mobile_payments.schemas import FreedomPaymentInitResponse
from ..mobile_payments.service import MobilePaymentService
from .dependencies import get_pass_service
from .schemas import (
    CustomerPassListResponse,
    CustomerPassQrResponse,
    CustomerPassResponse,
    GenericAdmissionRequest,
    PassInitRequest,
    PassPlanCreateRequest,
    PassPlanResponse,
    PassPlanUpdateRequest,
    PassQuoteRequest,
    PassQuoteResponse,
)
from .service import PassService

mobile_router = APIRouter()
admin_router = APIRouter()


@mobile_router.get('/passes/plans', response_model=list[PassPlanResponse])
def list_pass_plans(
    branchId: str | None = None,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: PassService = Depends(get_pass_service),
) -> list[PassPlanResponse]:
    return service.list_active_plans(branchId)


@mobile_router.get('/passes', response_model=CustomerPassListResponse)
def list_passes(
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: PassService = Depends(get_pass_service),
) -> CustomerPassListResponse:
    return service.list_for_user(auth_context.user.id)


@mobile_router.get('/passes/{pass_id}', response_model=CustomerPassResponse)
def get_pass(
    pass_id: str,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: PassService = Depends(get_pass_service),
) -> CustomerPassResponse:
    return service.get_for_user(pass_id, auth_context.user.id)


@mobile_router.get('/passes/{pass_id}/qr', response_model=CustomerPassQrResponse)
def get_pass_qr(
    pass_id: str,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: PassService = Depends(get_pass_service),
) -> CustomerPassQrResponse:
    return service.qr_for_user(pass_id, auth_context.user.id)


@mobile_router.post('/passes/freedom/quote', response_model=PassQuoteResponse)
def quote_pass(
    payload: PassQuoteRequest,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    service: PassService = Depends(get_pass_service),
) -> PassQuoteResponse:
    child, plan, branch = service.validate_purchase(
        user_id=auth_context.user.id, child_id=payload.childId,
        plan_id=payload.passPlanId, branch_id=payload.branchId,
    )
    return PassQuoteResponse(
        passPlan=service.plan_response(plan), childId=child.id, branchId=branch.id,
        amountTenge=plan.price_tenge,
    )


@mobile_router.post('/passes/freedom/init', response_model=FreedomPaymentInitResponse)
def init_pass(
    payload: PassInitRequest,
    auth_context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
    payment_service: MobilePaymentService = Depends(get_mobile_payment_service),
) -> FreedomPaymentInitResponse:
    return payment_service.init_freedom_pass_payment(user=auth_context.user, payload=payload)


@admin_router.get('/pass-plans', response_model=list[PassPlanResponse])
def admin_list_plans(
    current_admin_user: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin', 'content_manager')),
    service: PassService = Depends(get_pass_service),
) -> list[PassPlanResponse]:
    return service.list_admin_plans()


@admin_router.post('/pass-plans', response_model=PassPlanResponse, status_code=201)
def admin_create_plan(
    payload: PassPlanCreateRequest,
    current_admin_user: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin', 'content_manager')),
    service: PassService = Depends(get_pass_service),
) -> PassPlanResponse:
    return service.create_plan(payload)


@admin_router.patch('/pass-plans/{plan_id}', response_model=PassPlanResponse)
def admin_update_plan(
    plan_id: str,
    payload: PassPlanUpdateRequest,
    current_admin_user: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin', 'content_manager')),
    service: PassService = Depends(get_pass_service),
) -> PassPlanResponse:
    return service.update_plan(plan_id, payload)


@admin_router.get('/passes', response_model=CustomerPassListResponse)
def admin_list_passes(
    current_admin_user: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')),
    service: PassService = Depends(get_pass_service),
) -> CustomerPassListResponse:
    records = service.passes.list_all()
    items = [service.response(pass_record, child, branch) for pass_record, child, branch in records]
    return CustomerPassListResponse(items=items, total=len(items))


@admin_router.get('/passes/{pass_id}', response_model=CustomerPassResponse)
def admin_get_pass(
    pass_id: str,
    current_admin_user: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')),
    service: PassService = Depends(get_pass_service),
) -> CustomerPassResponse:
    record = service.passes.db.get(CustomerPass, pass_id)
    if record is None:
        raise NotFoundException(code='pass_not_found', message='Pass was not found.')
    child = service.children.get_by_id_and_user(record.child_id, record.mobile_user_id)
    branch = service.branches.get_by_id(record.branch_id_snapshot) if record.branch_id_snapshot else None
    if child is None:
        raise NotFoundException(code='pass_not_found', message='Pass was not found.')
    return service.response(record, child, branch)
