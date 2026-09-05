from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.models.loyalty_rule import LoyaltyRule
from ...db.repositories.loyalty_repository import LoyaltyRepository
from ..admin_auth.dependencies import require_admin_roles
from ..admin_auth.schemas import AdminCurrentUserResponse
from ..mobile_auth.dependencies import AuthenticatedMobileContext, get_current_mobile_auth_context
from .dependencies import get_loyalty_service
from .schemas import LoyaltyAccountResponse, LoyaltyRuleListResponse, LoyaltyRuleRequest, LoyaltyRuleResponse, LoyaltySettingsRequest, LoyaltySettingsResponse, LoyaltyTransactionListResponse
from .service import LoyaltyService, to_rule_response, to_settings_response, to_transaction_response, validate_rule

mobile_router = APIRouter()
admin_router = APIRouter()


@admin_router.get('/loyalty/settings', response_model=LoyaltySettingsResponse)
def get_settings(_: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')), service: LoyaltyService = Depends(get_loyalty_service)) -> LoyaltySettingsResponse:
    return LoyaltySettingsResponse(**to_settings_response(service.get_settings()))


@admin_router.patch('/loyalty/settings', response_model=LoyaltySettingsResponse)
def update_settings(payload: LoyaltySettingsRequest, _: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')), service: LoyaltyService = Depends(get_loyalty_service)) -> LoyaltySettingsResponse:
    settings = service.update_settings(max_redemption_percent=payload.maxRedemptionPercent, bonus_value_kzt=payload.bonusValueKzt)
    service.repository.db.commit()
    service.repository.db.refresh(settings)
    return LoyaltySettingsResponse(**to_settings_response(settings))


@mobile_router.get('/loyalty/account', response_model=LoyaltyAccountResponse, responses={401: {'model': ErrorResponse}})
def get_account(auth: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context), service: LoyaltyService = Depends(get_loyalty_service)) -> LoyaltyAccountResponse:
    return LoyaltyAccountResponse(**service.account_response(auth.user.id))


@mobile_router.get('/loyalty/transactions', response_model=LoyaltyTransactionListResponse, responses={401: {'model': ErrorResponse}})
def list_transactions(limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0), auth: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context), service: LoyaltyService = Depends(get_loyalty_service)) -> LoyaltyTransactionListResponse:
    items, total = service.list_transactions(auth.user.id, limit=limit, offset=offset)
    return LoyaltyTransactionListResponse(items=[to_transaction_response(item) for item in items], total=total, limit=limit, offset=offset)


@admin_router.get('/loyalty/rules', response_model=LoyaltyRuleListResponse)
def list_rules(_: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')), session: Session = Depends(get_db_session)) -> LoyaltyRuleListResponse:
    return LoyaltyRuleListResponse(items=[to_rule_response(rule) for rule in LoyaltyRepository(session).list_rules()])


@admin_router.post('/loyalty/rules', response_model=LoyaltyRuleResponse, status_code=status.HTTP_201_CREATED)
def create_rule(payload: LoyaltyRuleRequest, _: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')), session: Session = Depends(get_db_session)) -> LoyaltyRuleResponse:
    validate_rule(payload.eventType, payload.rewardType, payload.value, payload.startsAt, payload.endsAt)
    rule = LoyaltyRule(event_type=payload.eventType, reward_type=payload.rewardType, value=payload.value, is_active=payload.isActive, starts_at=payload.startsAt, ends_at=payload.endsAt)
    session.add(rule)
    session.commit()
    session.refresh(rule)
    return LoyaltyRuleResponse(**to_rule_response(rule))


@admin_router.patch('/loyalty/rules/{rule_id}', response_model=LoyaltyRuleResponse)
def update_rule(rule_id: str, payload: LoyaltyRuleRequest, _: AdminCurrentUserResponse = Depends(require_admin_roles('super_admin')), session: Session = Depends(get_db_session)) -> LoyaltyRuleResponse:
    validate_rule(payload.eventType, payload.rewardType, payload.value, payload.startsAt, payload.endsAt)
    rule = LoyaltyRepository(session).get_rule(rule_id)
    if rule is None:
        from ...core.exceptions.http import NotFoundException
        raise NotFoundException(code='loyalty_rule_not_found', message='Правило лояльности не найдено.')
    rule.event_type = payload.eventType
    rule.reward_type = payload.rewardType
    rule.value = payload.value
    rule.is_active = payload.isActive
    rule.starts_at = payload.startsAt
    rule.ends_at = payload.endsAt
    session.add(rule)
    session.commit()
    session.refresh(rule)
    return LoyaltyRuleResponse(**to_rule_response(rule))
