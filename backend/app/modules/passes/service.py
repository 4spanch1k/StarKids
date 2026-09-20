from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta
from uuid import uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy import select

from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...core.time.business_time import business_today
from ...db.models.admin_user import AdminUser
from ...db.models.branch import Branch
from ...db.models.customer_pass import CustomerPass
from ...db.models.mobile_child import MobileChild
from ...db.models.mobile_payment import MobilePayment
from ...db.models.pass_plan import PassPlan
from ...db.models.pass_redemption import PassRedemption
from ...db.models.visit import Visit
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.customer_pass_repository import CustomerPassRepository
from ...db.repositories.mobile_child_repository import MobileChildRepository
from ...db.repositories.pass_plan_repository import PassPlanRepository
from ...db.repositories.pass_redemption_repository import PassRedemptionRepository
from ...db.repositories.visit_repository import VisitRepository
from ..admin_tickets.branch_scope import require_active_branch_access
from .qr_service import PassQrService
from .schemas import (
    CustomerPassListResponse,
    CustomerPassQrResponse,
    CustomerPassResponse,
    PassPlanCreateRequest,
    PassPlanResponse,
    PassPlanUpdateRequest,
)


class PassService:
    def __init__(
        self,
        *,
        plan_repository: PassPlanRepository,
        customer_pass_repository: CustomerPassRepository,
        redemption_repository: PassRedemptionRepository,
        child_repository: MobileChildRepository,
        branch_repository: BranchRepository,
        visit_repository: VisitRepository,
        qr_service: PassQrService,
        now_provider: Callable[[], datetime] | None = None,
        business_date_provider: Callable[[], date] = business_today,
    ) -> None:
        self.plans = plan_repository
        self.passes = customer_pass_repository
        self.redemptions = redemption_repository
        self.children = child_repository
        self.branches = branch_repository
        self.visits = visit_repository
        self.qr = qr_service
        self.now_provider = now_provider or (lambda: datetime.now(UTC))
        self.business_date_provider = business_date_provider

    def list_active_plans(self, branch_id: str | None = None) -> list[PassPlanResponse]:
        return [self.plan_response(plan) for plan in self.plans.list_active(branch_id=branch_id)]

    def list_admin_plans(self) -> list[PassPlanResponse]:
        return [self.plan_response(plan) for plan in self.plans.list_all()]

    def create_plan(self, payload: PassPlanCreateRequest) -> PassPlanResponse:
        self._validate_daily_limit(payload.dailyLimit)
        if payload.branchId is not None and self.branches.get_active_by_id(payload.branchId) is None:
            raise NotFoundException(code='branch_not_found', message='Branch is not available.')
        plan = PassPlan(
            name=payload.name.strip(), price_tenge=payload.priceTenge,
            visit_limit=payload.visitLimit, validity_days=payload.validityDays,
            daily_limit=payload.dailyLimit, branch_id=payload.branchId, is_active=payload.isActive,
        )
        self.plans.add(plan)
        self.plans.db.commit()
        self.plans.db.refresh(plan)
        return self.plan_response(plan)

    def update_plan(self, plan_id: str, payload: PassPlanUpdateRequest) -> PassPlanResponse:
        plan = self.plans.get(plan_id, for_update=True)
        if plan is None:
            raise NotFoundException(code='pass_plan_not_found', message='Pass plan was not found.')
        values = payload.model_dump(exclude_unset=True)
        if 'dailyLimit' in values:
            self._validate_daily_limit(values['dailyLimit'])
        if values.get('branchId') is not None and self.branches.get_active_by_id(values['branchId']) is None:
            raise NotFoundException(code='branch_not_found', message='Branch is not available.')
        mapping = {
            'name': 'name', 'priceTenge': 'price_tenge', 'visitLimit': 'visit_limit',
            'validityDays': 'validity_days', 'dailyLimit': 'daily_limit',
            'branchId': 'branch_id', 'isActive': 'is_active',
        }
        for key, value in values.items():
            setattr(plan, mapping[key], value.strip() if key == 'name' else value)
        self.plans.db.add(plan)
        self.plans.db.commit()
        self.plans.db.refresh(plan)
        return self.plan_response(plan)

    @staticmethod
    def _validate_daily_limit(value: int) -> None:
        if value != 1:
            raise DomainHTTPException(
                code='unsupported_daily_limit',
                message='Pass V1 supports one admission per business day.',
                status_code=422,
            )

    def validate_purchase(
        self,
        *,
        user_id: str,
        child_id: str,
        plan_id: str,
        branch_id: str,
        for_update: bool = False,
    ) -> tuple[MobileChild, PassPlan, Branch]:
        child = self.children.get_by_id_and_user(child_id, user_id, for_update=for_update)
        if child is None:
            raise NotFoundException(code='child_not_found', message='Child was not found.')
        plan = self.plans.get(plan_id)
        if plan is None or not plan.is_active:
            raise NotFoundException(code='pass_plan_not_found', message='Pass plan is not available.')
        self._validate_daily_limit(plan.daily_limit)
        branch = self.branches.get_active_by_id(branch_id)
        if branch is None:
            raise NotFoundException(code='branch_not_found', message='Branch is not available.')
        if plan.branch_id is not None and plan.branch_id != branch.id:
            raise DomainHTTPException(code='wrong_branch', message='Pass plan is not available at this branch.', status_code=409)
        return child, plan, branch

    def issue_for_paid_payment(self, payment: MobilePayment) -> CustomerPass:
        existing = self.passes.get_by_payment_for_update(payment.id)
        if existing is not None:
            payment.pass_issuance_required = False
            self.passes.db.add(payment)
            self.passes.db.commit()
            return existing
        snapshot = dict(payment.init_payload or {}).get('passSnapshot')
        if not isinstance(snapshot, dict):
            raise DomainHTTPException(code='pass_snapshot_missing', message='Pass payment snapshot is missing.', status_code=409)
        child = self.children.get_by_id_and_user(
            str(snapshot.get('childId') or ''),
            payment.mobile_user_id,
            for_update=True,
        )
        if child is None:
            raise DomainHTTPException(
                code='pass_child_not_found',
                message='Pass child is no longer available for entitlement issuance.',
                status_code=409,
            )
        activated_at = payment.paid_at or self.now_provider()
        if activated_at.tzinfo is None:
            activated_at = activated_at.replace(tzinfo=UTC)
        validity_days = int(snapshot['validityDays'])
        expires_at = activated_at + timedelta(days=validity_days)
        now = self.now_provider()
        if now.tzinfo is None:
            now = now.replace(tzinfo=UTC)
        status = 'expired' if expires_at <= now else 'active'
        customer_pass = CustomerPass(
            mobile_user_id=payment.mobile_user_id,
            child_id=str(snapshot['childId']),
            mobile_payment_id=payment.id,
            pass_plan_id=str(snapshot['passPlanId']),
            name_snapshot=str(snapshot['planName']),
            price_tenge_snapshot=int(snapshot['priceTenge']),
            visit_limit_snapshot=int(snapshot['visitLimit']),
            validity_days_snapshot=validity_days,
            daily_limit_snapshot=int(snapshot['dailyLimit']),
            branch_id_snapshot=snapshot.get('branchId'),
            activated_at=activated_at,
            expires_at=expires_at,
            remaining_visits=int(snapshot['visitLimit']),
            status=status,
        )
        try:
            self.passes.add(customer_pass)
            self.passes.db.flush()
            payment.pass_issuance_required = False
            payment.issued_at = self.now_provider()
            self.passes.db.add(payment)
            self.passes.db.commit()
            self.passes.db.refresh(customer_pass)
            return customer_pass
        except IntegrityError:
            self.passes.db.rollback()
            existing = self.passes.get_by_payment_for_update(payment.id)
            if existing is None:
                raise
            return existing

    def list_for_user(self, user_id: str) -> CustomerPassListResponse:
        records = self.passes.list_for_user(user_id)
        changed = False
        for customer_pass, _, _ in records:
            before = customer_pass.status
            self._refresh_expiry(customer_pass, commit=False)
            changed = changed or before != customer_pass.status
        if changed:
            self.passes.db.commit()
        items = [self.response(customer_pass, child, branch) for customer_pass, child, branch in records]
        return CustomerPassListResponse(items=items, total=len(items))

    def get_for_user(self, pass_id: str, user_id: str) -> CustomerPassResponse:
        record = self.passes.get_for_user(pass_id, user_id)
        if record is None:
            raise NotFoundException(code='pass_not_found', message='Pass was not found.')
        child = self.children.get_by_id_and_user(record.child_id, user_id)
        branch = self.branches.get_by_id(record.branch_id_snapshot) if record.branch_id_snapshot else None
        if child is None:
            raise NotFoundException(code='pass_not_found', message='Pass was not found.')
        self._refresh_expiry(record)
        return self.response(record, child, branch)

    def qr_for_user(self, pass_id: str, user_id: str) -> CustomerPassQrResponse:
        record = self.passes.get_for_user(pass_id, user_id, for_update=True)
        if record is None:
            raise NotFoundException(code='pass_not_found', message='Pass was not found.')
        self._refresh_expiry(record)
        if record.status != 'active' or not self.qr.is_configured:
            raise NotFoundException(code='pass_qr_unavailable', message='QR is not available for this pass.')
        self.passes.db.commit()
        return CustomerPassQrResponse(passId=record.id, qrPayload=self.qr.build_payload(record.id))

    def redeem(self, *, qr_payload: str, branch_id: str, admin_user: AdminUser, source: str = 'scan', reason: str | None = None):
        require_active_branch_access(admin_user=admin_user, requested_branch_id=branch_id, branch_repository=self.branches)
        pass_id = self.qr.verify_payload(qr_payload)
        if pass_id is None:
            raise DomainHTTPException(code='invalid_qr', message='QR payload is invalid.')
        return self._redeem_pass(pass_id=pass_id, branch_id=branch_id, admin_user=admin_user, source=source, reason=reason)

    def redeem_manual(self, *, pass_id: str, branch_id: str, reason: str, admin_user: AdminUser):
        if not reason.strip():
            raise DomainHTTPException(code='manual_reason_required', message='A reason is required for manual redemption.')
        require_active_branch_access(admin_user=admin_user, requested_branch_id=branch_id, branch_repository=self.branches)
        return self._redeem_pass(pass_id=pass_id, branch_id=branch_id, admin_user=admin_user, source='manual', reason=reason)

    def _redeem_pass(self, *, pass_id: str, branch_id: str, admin_user: AdminUser, source: str, reason: str | None):
        now = self.now_provider()
        customer_pass = self.passes.get_for_user(pass_id, self._pass_owner(pass_id), for_update=True)
        if customer_pass is None:
            customer_pass = self.passes.db.get(CustomerPass, pass_id)
            if customer_pass is None:
                raise NotFoundException(code='pass_not_found', message='Pass was not found.')
            customer_pass = self.passes.db.scalar(select(CustomerPass).where(CustomerPass.id == pass_id).with_for_update())
        branch = self.branches.get_by_id(branch_id)
        if customer_pass.branch_id_snapshot is not None and customer_pass.branch_id_snapshot != branch_id:
            raise DomainHTTPException(code='wrong_branch', message='Pass belongs to another branch.', status_code=409)
        self._refresh_expiry(customer_pass, now=now, commit=False)
        if customer_pass.status == 'expired':
            self.passes.db.commit()
            raise DomainHTTPException(code='expired', message='Pass has expired.', status_code=409)
        business_date = self.business_date_provider()
        existing = self.redemptions.get_for_pass_date(customer_pass.id, business_date, for_update=True)
        if existing is not None:
            self.passes.db.rollback()
            return self._redemption_response('already_used_today', customer_pass, branch, existing)
        if customer_pass.status != 'active':
            self.passes.db.rollback()
            raise DomainHTTPException(code=customer_pass.status, message='Pass is not valid for redemption.', status_code=409)
        if customer_pass.remaining_visits <= 0:
            customer_pass.status = 'exhausted'
            self.passes.db.commit()
            raise DomainHTTPException(code='exhausted', message='Pass has no remaining visits.', status_code=409)
        visit = Visit(
            mobile_payment_id=None,
            mobile_user_id=customer_pass.mobile_user_id,
            child_id=customer_pass.child_id,
            branch_id=branch_id,
            status='active',
            started_at=now,
        )
        self.visits.add(visit)
        self.passes.db.flush()
        redemption = PassRedemption(
            customer_pass_id=customer_pass.id, visit_id=visit.id, branch_id=branch_id,
            redeemed_by_admin_user_id=admin_user.id, business_date=business_date,
            source=source, reason=reason, created_at=now, redeemed_at=now,
        )
        self.redemptions.add(redemption)
        customer_pass.remaining_visits -= 1
        if customer_pass.remaining_visits == 0:
            customer_pass.status = 'exhausted'
        self.passes.db.add(customer_pass)
        try:
            self.passes.db.commit()
        except IntegrityError:
            self.passes.db.rollback()
            locked = self.redemptions.get_for_pass_date(customer_pass.id, business_date)
            if locked is None:
                raise
            return self._redemption_response('already_used_today', customer_pass, branch, locked)
        return self._redemption_response('redeemed', customer_pass, branch, redemption)

    def _pass_owner(self, pass_id: str) -> str:
        # The QR itself is intentionally opaque. The owner lookup is done
        # directly after signature verification and never exposed to callers.
        owner = self.passes.db.scalar(select(CustomerPass.mobile_user_id).where(CustomerPass.id == pass_id))
        return str(owner or '')

    def _refresh_expiry(self, customer_pass: CustomerPass, *, now: datetime | None = None, commit: bool = True) -> None:
        effective_now = now or self.now_provider()
        expires_at = customer_pass.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=UTC)
        if effective_now.tzinfo is None:
            effective_now = effective_now.replace(tzinfo=UTC)
        if customer_pass.status == 'active' and expires_at <= effective_now:
            customer_pass.status = 'expired'
            self.passes.db.add(customer_pass)
            if commit:
                self.passes.db.commit()

    @staticmethod
    def plan_response(plan: PassPlan) -> PassPlanResponse:
        return PassPlanResponse(
            id=plan.id, name=plan.name, priceTenge=plan.price_tenge, visitLimit=plan.visit_limit,
            validityDays=plan.validity_days, dailyLimit=plan.daily_limit, branchId=plan.branch_id,
            isActive=plan.is_active,
        )

    @staticmethod
    def response(customer_pass: CustomerPass, child: MobileChild, branch: Branch | None) -> CustomerPassResponse:
        return CustomerPassResponse(
            id=customer_pass.id, childId=customer_pass.child_id, childName=child.name,
            passPlanId=customer_pass.pass_plan_id, planName=customer_pass.name_snapshot,
            priceTenge=customer_pass.price_tenge_snapshot, visitLimit=customer_pass.visit_limit_snapshot,
            validityDays=customer_pass.validity_days_snapshot, dailyLimit=customer_pass.daily_limit_snapshot,
            branchId=customer_pass.branch_id_snapshot, activatedAt=customer_pass.activated_at,
            expiresAt=customer_pass.expires_at, remainingVisits=customer_pass.remaining_visits,
            status=customer_pass.status,
        )

    def _redemption_response(self, outcome: str, customer_pass: CustomerPass, branch: Branch, redemption: PassRedemption):
        from .schemas import GenericAdmissionResponse
        child = self.children.get_by_id_and_user(customer_pass.child_id, customer_pass.mobile_user_id)
        return GenericAdmissionResponse(
            kind='pass', outcome=outcome, passId=customer_pass.id, planName=customer_pass.name_snapshot,
            childId=customer_pass.child_id, childName=child.name if child else None,
            remainingVisits=customer_pass.remaining_visits, visitLimit=customer_pass.visit_limit_snapshot,
            status=customer_pass.status,
            expiresAt=customer_pass.expires_at, branchId=branch.id, branchName=branch.name,
            visitId=redemption.visit_id, redeemedAt=redemption.redeemed_at,
        )
