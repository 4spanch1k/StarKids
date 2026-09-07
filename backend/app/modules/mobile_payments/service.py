from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal, InvalidOperation, ROUND_DOWN
import logging
from secrets import token_hex
from xml.etree import ElementTree

from fastapi import status
from sqlalchemy.exc import IntegrityError

from ...core.config.settings import Settings
from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...core.time.business_time import business_today
from ...db.models.branch import Branch
from ...db.models.issued_ticket import IssuedTicket
from ...db.models.mobile_payment import MobilePayment
from ...db.models.mobile_user import MobileUser
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.branch_ticket_repository import BranchTicketRepository
from ...db.repositories.mobile_payment_repository import MobilePaymentRepository
from ...db.repositories.visit_repository import VisitRepository
from .issued_ticket_service import IssuedTicketService
from .constants import (
    PAYABLE_BRANCH_TICKET_ORDER,
    PAYMENT_CURRENCY_KZT,
    PAYMENT_GATEWAY_FREEDOMPAY,
    PAYMENT_STATUS_CANCELED,
    PAYMENT_STATUS_EXPIRED,
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_PAID,
    PAYMENT_RESERVATION_TTL_MINUTES,
)
from .freedompay_client import (
    FreedomPayClientProtocol,
    FreedomPayGatewayError,
)
from .schemas import (
    FreedomPaymentInitRequest,
    FreedomPaymentInitResponse,
    FreedomPaymentQuoteRequest,
    FreedomPaymentQuoteResponse,
    MobilePaymentStatusResponse,
    PurchasedTicketLineItemResponse,
    PurchasedTicketResponse,
    PurchasedTicketsResponse,
    IssuedTicketResponse,
    IssuedTicketsResponse,
    IssuedTicketQrResponse,
    CurrentVisitResponse,
)
from .signing import (
    build_freedompay_signature,
    signature_script_from_url,
    verify_freedompay_signature,
)
from .ticket_qr_service import TicketQrService
from .visit_lifecycle import should_complete_visit
from ..loyalty.constants import LOYALTY_EVENT_TICKET_PURCHASE
from ..loyalty.service import LoyaltyService

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class FreedomPayCallbackResult:
    xml: str


@dataclass(frozen=True)
class TicketPaymentQuote:
    subtotal_tenge: int
    bonus_balance: int
    available_bonus_balance: int
    max_redemption_percent: Decimal
    max_redeemable_bonus: int
    requested_bonus_amount: int
    payable_tenge: int
    cashback_enabled: bool = False
    expected_cashback: int | None = None

    @property
    def bonus_spending_enabled(self) -> bool:
        return self.max_redeemable_bonus > 0


class MobilePaymentService:
    def __init__(
        self,
        *,
        settings: Settings,
        payment_repository: MobilePaymentRepository,
        branch_repository: BranchRepository,
        ticket_repository: BranchTicketRepository,
        freedompay_client: FreedomPayClientProtocol,
        issued_ticket_service: IssuedTicketService,
        ticket_qr_service: TicketQrService,
        visit_repository: VisitRepository,
        loyalty_service: LoyaltyService,
    ) -> None:
        self._settings = settings
        self._payment_repository = payment_repository
        self._branch_repository = branch_repository
        self._ticket_repository = ticket_repository
        self._freedompay_client = freedompay_client
        self._issued_ticket_service = issued_ticket_service
        self._ticket_qr_service = ticket_qr_service
        self._visit_repository = visit_repository
        self._loyalty_service = loyalty_service

    def init_freedom_ticket_payment(
        self,
        *,
        user: MobileUser,
        payload: FreedomPaymentInitRequest,
    ) -> FreedomPaymentInitResponse:
        self.expire_stale_payments()
        if self._settings.is_production and self._settings.freedompay_mock_mode:
            raise DomainHTTPException(
                code='freedompay_mock_disabled',
                message='Freedom Pay mock mode is disabled in production.',
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        if not self._settings.is_freedompay_configured and not self._settings.freedompay_mock_mode:
            raise DomainHTTPException(
                code='freedompay_not_configured',
                message='Freedom Pay is not configured on the backend.',
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        if payload.visitDate < business_today():
            raise DomainHTTPException(
                code='invalid_visit_date',
                message='Visit date must be today or later.',
            )

        existing_payment = self._payment_repository.get_by_idempotency_key_for_user(
            mobile_user_id=user.id,
            idempotency_key=payload.idempotencyKey,
        )
        if existing_payment is not None:
            if existing_payment.status != 'created' or existing_payment.payment_url:
                return _payment_init_response(existing_payment)
            payment = self._payment_repository.get_by_idempotency_key_for_user(
                mobile_user_id=user.id,
                idempotency_key=payload.idempotencyKey,
                for_update=True,
            )
            if payment is None:
                raise DomainHTTPException(
                    code='payment_init_race',
                    message='Payment initialization could not be locked safely.',
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            if payment.status != 'created' or payment.payment_url:
                return _payment_init_response(payment)

        branch, ticket_items = self._resolve_ticket_items(payload)
        quote = self._calculate_quote(
            user=user,
            gross_amount_tenge=sum(item['priceTenge'] * item['quantity'] for item in ticket_items),
            requested_bonus_amount=payload.requestedBonusAmount,
        )
        quantity = sum(item['quantity'] for item in ticket_items)
        if quote.subtotal_tenge <= 0:
            raise DomainHTTPException(
                code='invalid_payment_amount',
                message='Payment amount must be greater than zero.',
            )
        local_order_id = f'sk-{token_hex(12)}'
        initial_audit_payload = {
            'ticketItems': ticket_items,
            'gateway': PAYMENT_GATEWAY_FREEDOMPAY,
        }
        try:
            payment = self._payment_repository.create_ticket_payment(
                mobile_user_id=user.id,
                branch_id=branch.id,
                payable_entity_type=PAYABLE_BRANCH_TICKET_ORDER,
                payable_entity_id=branch.id,
                local_order_id=local_order_id,
                idempotency_key=payload.idempotencyKey,
                amount_tenge=quote.payable_tenge,
                currency=PAYMENT_CURRENCY_KZT,
                quantity=quantity,
                visit_date=payload.visitDate,
                ticket_items=ticket_items,
                init_payload=initial_audit_payload,
                gross_amount_tenge=quote.subtotal_tenge,
                bonus_amount=quote.requested_bonus_amount,
                cash_amount_tenge=quote.payable_tenge,
                expires_at=datetime.now(UTC)
                + timedelta(minutes=PAYMENT_RESERVATION_TTL_MINUTES),
            )
        except IntegrityError:
            self._payment_repository.db.rollback()
            payment = self._payment_repository.get_by_idempotency_key_for_user(
                mobile_user_id=user.id,
                idempotency_key=payload.idempotencyKey,
                for_update=True,
            )
            if payment is None:
                raise
            if payment.status != 'created' or payment.payment_url:
                return _payment_init_response(payment)
        else:
            payment = self._payment_repository.get_by_idempotency_key_for_user(
                mobile_user_id=user.id,
                idempotency_key=payload.idempotencyKey,
                for_update=True,
            )
            if payment is None:
                raise DomainHTTPException(
                    code='payment_init_race',
                    message='Payment initialization could not be locked safely.',
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                )

        payment = self._ensure_payment_snapshot(payment, quote)
        if payment.bonus_amount > 0:
            try:
                reservation = self._loyalty_service.reserve(
                    user_id=payment.mobile_user_id,
                    amount=payment.bonus_amount,
                    source_type='mobile_payment',
                    source_id=payment.id,
                    order_amount_kzt=payment.gross_amount_tenge,
                    idempotency_key=f'ticket_payment_reserve:{payment.id}',
                    description='Резерв бонусов для покупки билетов',
                )
                payment.loyalty_reservation_id = reservation.id
                self._payment_repository.db.flush()
            except Exception:
                self._payment_repository.mark_failed(
                    payment,
                    status=PAYMENT_STATUS_FAILED,
                    callback_payload={},
                    failure_reason='Bonus reservation failed.',
                )
                raise

        if payment.cash_amount_tenge == 0:
            return self._complete_zero_cash_payment(payment)

        gateway_request = self._build_freedompay_init_request(
            payment=payment,
            user=user,
            branch=branch,
        )

        try:
            gateway_result = self._freedompay_client.init_payment(gateway_request)
        except FreedomPayGatewayError as exc:
            self._release_payment_reservation(payment)
            self._payment_repository.mark_failed(
                payment,
                status=PAYMENT_STATUS_FAILED,
                callback_payload={},
                failure_reason=str(exc),
            )
            raise DomainHTTPException(
                code='freedompay_init_failed',
                message='Could not initialize payment in Freedom Pay.',
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            ) from exc

        payment = self._payment_repository.mark_pending(
            payment,
            external_payment_id=gateway_result.external_payment_id,
            payment_url=gateway_result.payment_url,
            init_payload={
                'gatewayRequest': _sanitize_gateway_payload(gateway_request),
                'gatewayResponse': _sanitize_gateway_payload(gateway_result.raw_payload),
                'ticketItems': ticket_items,
            },
        )

        return _payment_init_response(payment, payment_url=gateway_result.payment_url)

    def quote_ticket_payment(
        self,
        *,
        user: MobileUser,
        payload: FreedomPaymentQuoteRequest,
    ) -> FreedomPaymentQuoteResponse:
        if payload.visitDate < business_today():
            raise DomainHTTPException(code='invalid_visit_date', message='Visit date must be today or later.')
        _, ticket_items = self._resolve_ticket_items(payload)
        quote = self._calculate_quote(
            user=user,
            gross_amount_tenge=sum(item['priceTenge'] * item['quantity'] for item in ticket_items),
            requested_bonus_amount=payload.requestedBonusAmount,
        )
        return _quote_response(quote)

    def _calculate_quote(self, *, user: MobileUser, gross_amount_tenge: int, requested_bonus_amount: int) -> TicketPaymentQuote:
        if gross_amount_tenge <= 0:
            raise DomainHTTPException(code='invalid_payment_amount', message='Payment amount must be greater than zero.')
        if requested_bonus_amount < 0:
            raise DomainHTTPException(code='loyalty_invalid_amount', message='Количество бонусов не может быть отрицательным.', status_code=422)
        settings = self._loyalty_service.get_settings()
        account = self._loyalty_service.account_response(user.id)
        available = account['availableBalance']
        if settings.max_redemption_percent <= 0 and requested_bonus_amount > 0:
            raise DomainHTTPException(
                code='loyalty_spending_disabled',
                message='Списание бонусов пока недоступно.',
                status_code=409,
            )
        max_by_percent = int((Decimal(gross_amount_tenge) * settings.max_redemption_percent / Decimal('100')).to_integral_value(rounding=ROUND_DOWN))
        max_redeemable = min(available, max_by_percent)
        if requested_bonus_amount > max_by_percent:
            raise DomainHTTPException(code='loyalty_redemption_limit_exceeded', message='Сумма бонусов превышает допустимый лимит для заказа.', status_code=422)
        if requested_bonus_amount > available:
            raise DomainHTTPException(code='loyalty_insufficient_balance', message='Недостаточно доступных бонусов.', status_code=409)
        cashback_enabled, expected_cashback = self._loyalty_service.preview_event_reward(
            event_type=LOYALTY_EVENT_TICKET_PURCHASE,
            cash_amount_kzt=gross_amount_tenge - requested_bonus_amount,
        )
        return TicketPaymentQuote(
            subtotal_tenge=gross_amount_tenge,
            bonus_balance=account['balance'],
            available_bonus_balance=available,
            max_redemption_percent=settings.max_redemption_percent,
            max_redeemable_bonus=max_redeemable,
            requested_bonus_amount=requested_bonus_amount,
            payable_tenge=gross_amount_tenge - requested_bonus_amount,
            cashback_enabled=cashback_enabled,
            expected_cashback=expected_cashback,
        )

    def _ensure_payment_snapshot(self, payment: MobilePayment, quote: TicketPaymentQuote) -> MobilePayment:
        if payment.gross_amount_tenge == 0:
            payment.gross_amount_tenge = quote.subtotal_tenge
            payment.bonus_amount = quote.requested_bonus_amount
            payment.cash_amount_tenge = quote.payable_tenge
            payment.amount_tenge = quote.payable_tenge
            self._payment_repository.db.flush()
        return payment

    def get_payment_status(
        self,
        *,
        payment_id: str,
        mobile_user_id: str,
    ) -> MobilePaymentStatusResponse:
        self.expire_stale_payments()
        payment = self._payment_repository.get_by_id_for_user(
            payment_id=payment_id,
            mobile_user_id=mobile_user_id,
        )
        if payment is None:
            raise NotFoundException(
                code='payment_not_found',
                message='Payment was not found.',
            )
        return _payment_status_response(payment)

    def expire_stale_payments(self, *, now: datetime | None = None) -> int:
        now = now or datetime.now(UTC)
        expired = 0
        for payment in self._payment_repository.list_expired_pending(now=now):
            if payment.status not in {'created', 'pending'}:
                continue
            payment.status = PAYMENT_STATUS_EXPIRED
            payment.failure_reason = 'Payment reservation expired.'
            self._release_payment_reservation(payment)
            self._payment_repository.db.add(payment)
            expired += 1
        if expired:
            self._payment_repository.db.commit()
        return expired

    def settle_paid_loyalty(self) -> int:
        """Reconcile paid payments without blocking admission.

        Ticket delivery is the critical payment outcome. A transient ticket or
        loyalty failure therefore leaves the payment committed and marks the
        missing step for this idempotent reconciliation pass.
        """
        reconciled = 0
        for payment in self._payment_repository.list_paid_ticket_payments():
            try:
                delivered = self._issue_paid_payment_tickets(payment.id)
                settled = self._settle_paid_payment_loyalty(payment.id)
                if delivered or settled:
                    reconciled += 1
            except Exception:
                self._payment_repository.db.rollback()
                logger.exception(
                    'Paid payment reconciliation failed payment_id=%s',
                    payment.id,
                )
        return reconciled

    def list_paid_tickets(self, mobile_user_id: str) -> PurchasedTicketsResponse:
        records = self._payment_repository.list_paid_ticket_payments_for_user(mobile_user_id)
        items = [
            _purchased_ticket_response(payment=payment, branch=branch)
            for payment, branch in records
        ]
        return PurchasedTicketsResponse(items=items, total=len(items))

    def list_issued_tickets(self, mobile_user_id: str) -> IssuedTicketsResponse:
        records = self._issued_ticket_service.list_for_user(mobile_user_id)
        items = [
            _issued_ticket_response(ticket=ticket, branch=branch)
            for ticket, branch in records
        ]
        return IssuedTicketsResponse(items=items, total=len(items))

    def get_current_visit(self, mobile_user_id: str) -> CurrentVisitResponse | None:
        visit = self._visit_repository.get_active_for_user(mobile_user_id)
        if visit is None:
            return None
        payment = self._payment_repository.get_by_id(visit.mobile_payment_id)
        branch = self._branch_repository.get_by_id(visit.branch_id)
        now = datetime.now(UTC)
        if should_complete_visit(
            visit=visit,
            payment_visit_date=payment.visit_date if payment is not None else None,
            branch=branch,
            now=now,
        ):
            # Re-read under a row lock before completing so a concurrent
            # redemption/current-visit request cannot overwrite the state.
            locked = self._visit_repository.get_for_payment(
                visit.mobile_payment_id,
                for_update=True,
            )
            if locked is not None and locked.status == 'active':
                locked.status = 'completed'
                locked.ended_at = now
                locked.completion_reason = 'validity_cutoff'
                self._visit_repository.db.add(locked)
                self._visit_repository.db.commit()
                logger.info(
                    'Visit completed by validity cutoff visit_id=%s payment_id=%s',
                    locked.id,
                    locked.mobile_payment_id,
                )
            return None
        return CurrentVisitResponse(
            visitId=visit.id,
            branchId=visit.branch_id,
            branchName=branch.name if branch is not None else 'Boom Bala',
            status=visit.status,
            startedAt=visit.started_at,
        )

    def get_issued_ticket(
        self,
        *,
        ticket_id: str,
        mobile_user_id: str,
    ) -> IssuedTicketResponse:
        record = self._issued_ticket_service.get_for_user(
            ticket_id=ticket_id,
            mobile_user_id=mobile_user_id,
        )
        if record is None:
            raise NotFoundException(
                code='ticket_not_found',
                message='Ticket was not found.',
            )
        ticket, branch = record
        return _issued_ticket_response(ticket=ticket, branch=branch)

    def get_issued_ticket_qr(
        self,
        *,
        ticket_id: str,
        mobile_user_id: str,
    ) -> IssuedTicketQrResponse:
        record = self._issued_ticket_service.get_for_user(
            ticket_id=ticket_id,
            mobile_user_id=mobile_user_id,
        )
        if record is None:
            raise NotFoundException(
                code='ticket_not_found',
                message='Ticket was not found.',
            )
        ticket, _ = record
        if ticket.status != 'issued':
            raise NotFoundException(
                code='ticket_qr_unavailable',
                message='QR is not available for this ticket.',
            )
        if not self._ticket_qr_service.is_configured:
            raise NotFoundException(
                code='ticket_qr_unavailable',
                message='QR is not configured for this environment.',
            )
        return IssuedTicketQrResponse(
            ticketId=ticket.id,
            qrPayload=self._ticket_qr_service.build_payload(ticket.id),
        )

    def handle_freedompay_result(self, payload: dict[str, str]) -> FreedomPayCallbackResult:
        script_name = signature_script_from_url(
            self._settings.freedompay_result_url,
            fallback='result',
        )
        secret_key = self._settings.freedompay_secret_key
        if not secret_key:
            logger.error('Freedom Pay callback received before secret key was configured.')
            return self._gateway_response(
                status='error',
                description='Merchant is not configured',
                salt=_response_salt(payload, 'config'),
            )

        if not verify_freedompay_signature(
            script_name=script_name,
            params=payload,
            secret_key=secret_key,
        ):
            logger.warning('Freedom Pay callback rejected because signature is invalid.')
            return self._gateway_response(
                status='error',
                description='Invalid signature',
                salt=_response_salt(payload, 'signature'),
            )

        local_order_id = payload.get('pg_order_id')
        if not local_order_id:
            return self._gateway_response(
                status='error',
                description='Missing order id',
                salt=_response_salt(payload, 'order'),
            )

        payment = self._payment_repository.get_by_local_order_id(local_order_id)
        if payment is None:
            logger.warning('Freedom Pay callback references unknown order %s.', local_order_id)
            return self._gateway_response(
                status='rejected',
                description='Order not found',
                salt=_response_salt(payload, 'not-found'),
            )

        gateway_result = payload.get('pg_result')
        callback_payload = _sanitize_gateway_payload(payload)
        validation_reason: str | None = None
        validation_description = 'Payment callback validation failed'
        if gateway_result == '1':
            validation_reason = _success_callback_validation_reason(payment, payload)
        elif not _callback_amount_matches(payment, payload):
            # Preserve the existing reconciliation guard for non-success
            # callbacks without applying the stricter success contract to
            # provider failure/not-completed payloads.
            validation_reason = 'amount_or_currency_mismatch'
            validation_description = 'Payment amount mismatch'

        if validation_reason is not None:
            can_reject = payload.get('pg_can_reject') != '0'
            audit_result = 'rejected' if can_reject else 'reconciliation_required'
            if not can_reject:
                logger.error(
                    'Freedom Pay callback validation mismatch requires reconciliation: '
                    'payment_id=%s local_order_id=%s provider_event_id=%s reason=%s.',
                    payment.id,
                    payment.local_order_id,
                    payload.get('pg_payment_id'),
                    validation_reason,
                )
            self._payment_repository.record_rejected_callback(
                payment_id=payment.id,
                local_order_id=payment.local_order_id,
                payload=callback_payload,
                reason=(
                    f'Gateway success callback validation failed: {validation_reason}.'
                    if gateway_result == '1'
                    else 'Gateway callback amount or currency does not match local order.'
                ),
                audit_result=audit_result,
            )
            return self._gateway_response(
                status='rejected' if can_reject else 'ok',
                description=(
                    validation_description
                    if can_reject
                    else 'Payment validation mismatch; reconciliation required'
                ),
                salt=_response_salt(payload, payment.status),
            )

        external_payment_id = payload.get('pg_payment_id')
        if gateway_result == '1':
            self._process_successful_callback_atomically(
                payment=payment,
                payload=callback_payload,
                external_payment_id=external_payment_id,
                paid_at=_parse_gateway_datetime(payload.get('pg_payment_date')),
            )
            return self._gateway_response(
                status='ok',
                description='Order paid',
                salt=_response_salt(payload, PAYMENT_STATUS_PAID),
            )

        if gateway_result == '2':
            self._payment_repository.process_not_completed_callback(
                payment_id=payment.id,
                local_order_id=payment.local_order_id,
                payload=callback_payload,
            )
            return self._gateway_response(
                status='ok',
                description='Payment is not completed yet',
                salt=_response_salt(payload, payment.status),
            )

        failure_reason = (
            payload.get('pg_error_description')
            or payload.get('pg_failure_description')
            or 'Payment was not completed.'
        )
        self._process_failed_callback_atomically(
            payment_id=payment.id,
            local_order_id=payment.local_order_id,
            payload=callback_payload,
            external_payment_id=external_payment_id,
            failure_status=_failure_status_from_payload(payload),
            failure_reason=failure_reason,
        )
        return self._gateway_response(
            status='rejected',
            description='Payment cancelled',
            salt=_response_salt(payload, PAYMENT_STATUS_FAILED),
        )

    def _process_successful_callback_atomically(
        self,
        *,
        payment: MobilePayment,
        payload: dict[str, object],
        external_payment_id: str | None,
        paid_at: datetime | None,
    ) -> None:
        try:
            status_before_callback = payment.status
            processed_payment = self._payment_repository.process_verified_callback(
                payment_id=payment.id,
                local_order_id=payment.local_order_id,
                payload=payload,
                success=True,
                external_payment_id=external_payment_id,
                paid_at=paid_at,
                failure_status=None,
                failure_reason=None,
                commit=False,
            )
            should_reconcile_paid_payment = (
                processed_payment is not None
                and processed_payment.status == PAYMENT_STATUS_PAID
                and (
                    status_before_callback != PAYMENT_STATUS_PAID
                    or processed_payment.ticket_issuance_required
                    or processed_payment.loyalty_settlement_required
                )
            )
            if should_reconcile_paid_payment:
                processed_payment.loyalty_settlement_required = True
                processed_payment.ticket_issuance_required = True
                self._payment_repository.db.add(processed_payment)
            else:
                # Keep the callback audit transaction durable even when this
                # is a duplicate/terminal callback.
                self._payment_repository.db.commit()
                return
            self._payment_repository.db.commit()
        except Exception:
            self._payment_repository.db.rollback()
            raise

        ticket_delivery_ready = False
        try:
            self._issue_paid_payment_tickets(processed_payment.id)
            ticket_delivery_ready = True
        except Exception:
            self._payment_repository.db.rollback()
            logger.exception(
                'Payment paid but ticket issuance is pending payment_id=%s',
                processed_payment.id,
            )

        # Admission must not be rolled back by a loyalty outage. Settlement
        # has its own idempotent transaction and is retried by the cleanup
        # scheduler (or by a provider callback replay).
        if ticket_delivery_ready:
            try:
                self._settle_paid_payment_loyalty(processed_payment.id)
            except Exception:
                self._payment_repository.db.rollback()
                logger.exception(
                    'Payment paid and tickets issued, loyalty settlement pending payment_id=%s',
                    processed_payment.id,
                )

    def _process_failed_callback_atomically(
        self,
        *,
        payment_id: str,
        local_order_id: str,
        payload: dict[str, object],
        external_payment_id: str | None,
        failure_status: str,
        failure_reason: str,
    ) -> None:
        try:
            processed_payment = self._payment_repository.process_verified_callback(
                payment_id=payment_id,
                local_order_id=local_order_id,
                payload=payload,
                success=False,
                external_payment_id=external_payment_id,
                paid_at=None,
                failure_status=failure_status,
                failure_reason=failure_reason,
                commit=False,
            )
            if processed_payment is not None and processed_payment.status in {
                PAYMENT_STATUS_FAILED,
                PAYMENT_STATUS_CANCELED,
                PAYMENT_STATUS_EXPIRED,
            }:
                self._release_payment_reservation(processed_payment)
            self._payment_repository.db.commit()
        except Exception:
            self._payment_repository.db.rollback()
            raise

    def _complete_zero_cash_payment(self, payment: MobilePayment) -> FreedomPaymentInitResponse:
        try:
            payment.status = PAYMENT_STATUS_PAID
            payment.paid_at = datetime.now(UTC)
            payment.failure_reason = None
            payment.loyalty_settlement_required = True
            payment.ticket_issuance_required = True
            self._payment_repository.db.add(payment)
            self._payment_repository.db.commit()
        except Exception:
            self._payment_repository.db.rollback()
            raise
        ticket_delivery_ready = False
        try:
            self._issue_paid_payment_tickets(payment.id)
            ticket_delivery_ready = True
        except Exception:
            self._payment_repository.db.rollback()
            logger.exception(
                'Zero-cash payment paid but ticket issuance is pending payment_id=%s',
                payment.id,
            )
        if ticket_delivery_ready:
            try:
                self._settle_paid_payment_loyalty(payment.id)
            except Exception:
                self._payment_repository.db.rollback()
                logger.exception(
                    'Zero-cash payment paid and tickets issued, loyalty settlement pending payment_id=%s',
                    payment.id,
                )
        return _payment_init_response(payment, payment_url='')

    def _issue_paid_payment_tickets(self, payment_id: str) -> bool:
        payment = self._payment_repository.get_by_id_for_update(payment_id)
        if payment is None or payment.status != PAYMENT_STATUS_PAID:
            return False
        if not payment.ticket_issuance_required:
            return True
        try:
            self._issued_ticket_service.issue_tickets_for_paid_payment(payment)
            payment.ticket_issuance_required = False
            self._payment_repository.db.add(payment)
            self._payment_repository.db.commit()
            return True
        except Exception:
            self._payment_repository.db.rollback()
            raise

    def _settle_paid_payment_loyalty(self, payment_id: str) -> bool:
        payment = self._payment_repository.get_by_id_for_update(payment_id)
        if payment is None or payment.status != PAYMENT_STATUS_PAID:
            return False
        self._capture_payment_reservation(payment)
        self._loyalty_service.apply_event(
            user_id=payment.mobile_user_id,
            event_type='ticket_purchase',
            source_type='mobile_payment',
            source_id=payment.id,
            cash_amount_kzt=payment.cash_amount_tenge or payment.amount_tenge,
            idempotency_key=f'ticket_purchase:{payment.id}',
            metadata={'paymentId': payment.id},
        )
        payment.loyalty_settlement_required = False
        self._payment_repository.db.add(payment)
        self._payment_repository.db.commit()
        return True

    def _capture_payment_reservation(self, payment: MobilePayment) -> None:
        if payment.bonus_amount <= 0:
            return
        reservation = self._loyalty_service.reservation_for_source(
            source_type='mobile_payment',
            source_id=payment.id,
        )
        if reservation is None or reservation.status != 'reserved':
            if reservation is not None and reservation.status in {'captured', 'released'}:
                return
            raise DomainHTTPException(code='loyalty_reservation_not_found', message='Резерв бонусов для платежа не найден.', status_code=409)
        captured = self._loyalty_service.capture(
            user_id=payment.mobile_user_id,
            reservation_id=reservation.id,
            idempotency_key=f'ticket_payment_capture:{payment.id}',
        )
        payment.loyalty_reservation_id = captured.source_id

    def _release_payment_reservation(self, payment: MobilePayment) -> None:
        if payment.bonus_amount <= 0:
            return
        reservation = self._loyalty_service.reservation_for_source(
            source_type='mobile_payment',
            source_id=payment.id,
        )
        if reservation is None or reservation.status != 'reserved':
            return
        released = self._loyalty_service.release(
            user_id=payment.mobile_user_id,
            reservation_id=reservation.id,
            idempotency_key=f'ticket_payment_release:{payment.id}',
        )
        payment.loyalty_reservation_id = released.source_id

    def _resolve_ticket_items(
        self,
        payload: FreedomPaymentInitRequest,
    ) -> tuple[Branch, list[dict[str, object]]]:
        quantities_by_ticket_id: dict[str, int] = {}
        for item in payload.ticketItems:
            quantities_by_ticket_id[item.ticketItemId] = (
                quantities_by_ticket_id.get(item.ticketItemId, 0) + item.quantity
            )

        branch_id: str | None = None
        ticket_items: list[dict[str, object]] = []
        for ticket_item_id, quantity in quantities_by_ticket_id.items():
            ticket_item = self._ticket_repository.get_active_item(ticket_item_id)
            if ticket_item is None:
                raise NotFoundException(
                    code='ticket_not_found',
                    message='Ticket is not available for purchase.',
                )
            if branch_id is None:
                branch_id = ticket_item.branch_id
            elif branch_id != ticket_item.branch_id:
                raise DomainHTTPException(
                    code='mixed_branch_ticket_order',
                    message='All ticket items in one payment must belong to one branch.',
                )
            ticket_items.append(
                {
                    'ticketItemId': ticket_item.id,
                    'title': ticket_item.title,
                    'priceTenge': ticket_item.price_tenge,
                    'quantity': quantity,
                }
            )

        if branch_id is None:
            raise DomainHTTPException(
                code='empty_ticket_order',
                message='Select at least one ticket.',
            )

        branch = self._branch_repository.get_active_by_id(branch_id)
        if branch is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Branch is not available.',
            )
        return branch, ticket_items

    def _build_freedompay_init_request(
        self,
        *,
        payment: MobilePayment,
        user: MobileUser,
        branch: Branch,
    ) -> dict[str, object]:
        params: dict[str, object] = {
            'pg_order_id': payment.local_order_id,
            'pg_merchant_id': self._settings.freedompay_merchant_id or 'mock-merchant',
            'pg_amount': str(payment.amount_tenge),
            'pg_description': f'Boom Bala tickets: {branch.name}',
            'pg_currency': payment.currency,
            'pg_salt': token_hex(8),
            'pg_result_url': self._settings.freedompay_result_url or '',
            'pg_request_method': 'POST',
            'pg_success_url': self._settings.freedompay_success_url or '',
            'pg_failure_url': self._settings.freedompay_failure_url or '',
            'pg_success_url_method': 'GET',
            'pg_failure_url_method': 'GET',
            'pg_user_id': user.id,
            'pg_language': 'ru',
        }
        if self._settings.freedompay_testing_mode:
            params['pg_testing_mode'] = '1'
        if user.phone:
            params['pg_user_phone'] = user.phone
        if user.email:
            params['pg_user_contact_email'] = str(user.email)
        return params

    def _gateway_response(
        self,
        *,
        status: str,
        description: str,
        salt: str,
    ) -> FreedomPayCallbackResult:
        secret_key = self._settings.freedompay_secret_key or ''
        script_name = signature_script_from_url(
            self._settings.freedompay_result_url,
            fallback='result',
        )
        response_params: dict[str, object] = {
            'pg_status': status,
            'pg_description': description,
            'pg_salt': salt,
        }
        response_params['pg_sig'] = build_freedompay_signature(
            script_name=script_name,
            params=response_params,
            secret_key=secret_key,
        )
        return FreedomPayCallbackResult(xml=_build_xml_response(response_params))


def _payment_status_response(payment: MobilePayment) -> MobilePaymentStatusResponse:
    return MobilePaymentStatusResponse(
        paymentId=payment.id,
        localOrderId=payment.local_order_id,
        externalPaymentId=payment.external_payment_id,
        amountTenge=payment.amount_tenge,
        grossAmountTenge=payment.gross_amount_tenge or payment.amount_tenge,
        bonusAmount=payment.bonus_amount,
        cashAmountTenge=payment.cash_amount_tenge or payment.amount_tenge,
        currency=payment.currency,
        status=payment.status,
        failureReason=payment.failure_reason,
        paidAt=payment.paid_at,
    )


def _payment_init_response(
    payment: MobilePayment,
    *,
    payment_url: str | None = None,
) -> FreedomPaymentInitResponse:
    return FreedomPaymentInitResponse(
        paymentId=payment.id,
        localOrderId=payment.local_order_id,
        externalPaymentId=payment.external_payment_id,
        paymentUrl=payment_url or payment.payment_url or '',
        status=payment.status,
        grossAmountTenge=payment.gross_amount_tenge or payment.amount_tenge,
        bonusAmount=payment.bonus_amount,
        cashAmountTenge=payment.cash_amount_tenge or payment.amount_tenge,
    )


def _quote_response(quote: TicketPaymentQuote) -> FreedomPaymentQuoteResponse:
    return FreedomPaymentQuoteResponse(
        subtotalTenge=quote.subtotal_tenge,
        bonusBalance=quote.bonus_balance,
        availableBonusBalance=quote.available_bonus_balance,
        maxRedemptionPercent=str(quote.max_redemption_percent),
        maxRedeemableBonus=quote.max_redeemable_bonus,
        requestedBonusAmount=quote.requested_bonus_amount,
        payableTenge=quote.payable_tenge,
        bonusSpendingEnabled=quote.bonus_spending_enabled,
        cashbackEnabled=quote.cashback_enabled,
        expectedCashback=quote.expected_cashback,
    )


def _purchased_ticket_response(
    *,
    payment: MobilePayment,
    branch: Branch | None,
) -> PurchasedTicketResponse:
    return PurchasedTicketResponse(
        paymentId=payment.id,
        localOrderId=payment.local_order_id,
        branchId=payment.branch_id,
        branchName=branch.name if branch is not None else 'Boom Bala',
        visitDate=payment.visit_date,
        amountTenge=payment.amount_tenge,
        currency=payment.currency,
        paidAt=payment.paid_at,
        items=[
            PurchasedTicketLineItemResponse(
                ticketItemId=str(item.get('ticketItemId') or ''),
                title=str(item.get('title') or 'Билет'),
                priceTenge=int(item.get('priceTenge') or 0),
                quantity=int(item.get('quantity') or 0),
            )
            for item in payment.ticket_items
        ],
    )


def _issued_ticket_response(
    *,
    ticket: IssuedTicket,
    branch: Branch | None,
) -> IssuedTicketResponse:
    return IssuedTicketResponse(
        ticketId=ticket.id,
        ticketNumber=ticket.ticket_number,
        ticketItemId=ticket.ticket_item_id,
        title=ticket.title_snapshot,
        branchId=ticket.branch_id,
        branchName=branch.name if branch is not None else 'Boom Bala',
        visitDate=ticket.visit_date,
        priceTenge=ticket.price_tenge,
        status=ticket.status,
        issuedAt=ticket.issued_at,
    )


def _sanitize_gateway_payload(payload: dict[str, object]) -> dict[str, object]:
    sanitized: dict[str, object] = {}
    for key, value in payload.items():
        normalized_key = key.lower()
        if key == 'pg_sig':
            sanitized[key] = '[signature]'
        elif any(marker in normalized_key for marker in ('phone', 'email', 'card', 'pan')):
            sanitized[key] = '[redacted]'
        else:
            sanitized[key] = value
    return sanitized


def _success_callback_validation_reason(
    payment: MobilePayment,
    payload: dict[str, str],
) -> str | None:
    raw_provider_payment_id = payload.get('pg_payment_id')
    provider_payment_id = (
        str(raw_provider_payment_id)
        if raw_provider_payment_id is not None
        else ''
    )
    if not provider_payment_id.strip():
        return 'missing_provider_payment_id'
    if not payment.external_payment_id or not str(payment.external_payment_id).strip():
        return 'local_provider_payment_id_missing'
    if provider_payment_id != payment.external_payment_id:
        return 'provider_payment_id_mismatch'

    raw_amount = payload.get('pg_amount')
    if raw_amount is None or not str(raw_amount).strip():
        return 'missing_amount'
    try:
        callback_amount = Decimal(str(raw_amount).strip())
    except (InvalidOperation, TypeError, ValueError):
        return 'invalid_amount'
    if not callback_amount.is_finite():
        return 'invalid_amount'
    if callback_amount != Decimal(payment.amount_tenge):
        return 'amount_mismatch'

    raw_currency = payload.get('pg_currency')
    currency = str(raw_currency) if raw_currency is not None else ''
    if not currency.strip():
        return 'missing_currency'
    if currency != payment.currency:
        return 'currency_mismatch'
    return None


def _callback_amount_matches(payment: MobilePayment, payload: dict[str, str]) -> bool:
    if payload.get('pg_currency') and payload.get('pg_currency') != payment.currency:
        return False
    raw_amount = payload.get('pg_amount')
    if raw_amount is None:
        return True
    try:
        return Decimal(raw_amount) == Decimal(payment.amount_tenge)
    except InvalidOperation:
        return False


def _parse_gateway_datetime(raw_value: str | None) -> datetime | None:
    if not raw_value:
        return None
    for date_format in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S'):
        try:
            return datetime.strptime(raw_value, date_format).replace(tzinfo=UTC)
        except ValueError:
            continue
    return None


def _failure_status_from_payload(payload: dict[str, str]) -> str:
    failure_text = ' '.join(
        str(payload.get(key) or '').lower()
        for key in ('pg_failure_description', 'pg_error_description')
    )
    if 'cancel' in failure_text or 'отмен' in failure_text:
        return PAYMENT_STATUS_CANCELED
    return PAYMENT_STATUS_FAILED


def _response_salt(payload: dict[str, str], reason: str) -> str:
    order_id = payload.get('pg_order_id') or 'unknown'
    payment_id = payload.get('pg_payment_id') or 'none'
    return f'starkids-{order_id}-{payment_id}-{reason}'


def _build_xml_response(params: dict[str, object]) -> str:
    root = ElementTree.Element('response')
    for key in ('pg_status', 'pg_description', 'pg_salt', 'pg_sig'):
        child = ElementTree.SubElement(root, key)
        child.text = str(params[key])
    xml_body = ElementTree.tostring(root, encoding='unicode')
    return f'<?xml version="1.0" encoding="utf-8"?>\n{xml_body}'
