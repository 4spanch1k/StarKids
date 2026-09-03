from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation
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
from .issued_ticket_service import IssuedTicketService
from .constants import (
    PAYABLE_BRANCH_TICKET_ORDER,
    PAYMENT_CURRENCY_KZT,
    PAYMENT_GATEWAY_FREEDOMPAY,
    PAYMENT_STATUS_CANCELED,
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_PAID,
)
from .freedompay_client import (
    FreedomPayClientProtocol,
    FreedomPayGatewayError,
)
from .schemas import (
    FreedomPaymentInitRequest,
    FreedomPaymentInitResponse,
    MobilePaymentStatusResponse,
    PurchasedTicketLineItemResponse,
    PurchasedTicketResponse,
    PurchasedTicketsResponse,
    IssuedTicketResponse,
    IssuedTicketsResponse,
    IssuedTicketQrResponse,
)
from .signing import (
    build_freedompay_signature,
    signature_script_from_url,
    verify_freedompay_signature,
)
from .ticket_qr_service import TicketQrService

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class FreedomPayCallbackResult:
    xml: str


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
    ) -> None:
        self._settings = settings
        self._payment_repository = payment_repository
        self._branch_repository = branch_repository
        self._ticket_repository = ticket_repository
        self._freedompay_client = freedompay_client
        self._issued_ticket_service = issued_ticket_service
        self._ticket_qr_service = ticket_qr_service

    def init_freedom_ticket_payment(
        self,
        *,
        user: MobileUser,
        payload: FreedomPaymentInitRequest,
    ) -> FreedomPaymentInitResponse:
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

        branch, ticket_items = self._resolve_ticket_items(payload)
        amount_tenge = sum(item['priceTenge'] * item['quantity'] for item in ticket_items)
        quantity = sum(item['quantity'] for item in ticket_items)
        if amount_tenge <= 0:
            raise DomainHTTPException(
                code='invalid_payment_amount',
                message='Payment amount must be greater than zero.',
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
        else:
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
                    amount_tenge=amount_tenge,
                    currency=PAYMENT_CURRENCY_KZT,
                    quantity=quantity,
                    visit_date=payload.visitDate,
                    ticket_items=ticket_items,
                    init_payload=initial_audit_payload,
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

        gateway_request = self._build_freedompay_init_request(
            payment=payment,
            user=user,
            branch=branch,
        )

        try:
            gateway_result = self._freedompay_client.init_payment(gateway_request)
        except FreedomPayGatewayError as exc:
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

    def get_payment_status(
        self,
        *,
        payment_id: str,
        mobile_user_id: str,
    ) -> MobilePaymentStatusResponse:
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

        callback_payload = _sanitize_gateway_payload(payload)
        if not _callback_amount_matches(payment, payload):
            can_reject = payload.get('pg_can_reject') != '0'
            audit_result = 'rejected' if can_reject else 'reconciliation_required'
            if not can_reject:
                logger.error(
                    'Freedom Pay callback validation mismatch requires reconciliation: '
                    'payment_id=%s local_order_id=%s provider_event_id=%s.',
                    payment.id,
                    payment.local_order_id,
                    payload.get('pg_payment_id'),
                )
            self._payment_repository.record_rejected_callback(
                payment_id=payment.id,
                local_order_id=payment.local_order_id,
                payload=callback_payload,
                reason='Gateway callback amount or currency does not match local order.',
                audit_result=audit_result,
            )
            return self._gateway_response(
                status='rejected' if can_reject else 'ok',
                description=(
                    'Payment amount mismatch'
                    if can_reject
                    else 'Payment validation mismatch; reconciliation required'
                ),
                salt=_response_salt(payload, payment.status),
            )

        external_payment_id = payload.get('pg_payment_id')
        gateway_result = payload.get('pg_result')
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
        self._payment_repository.process_verified_callback(
            payment_id=payment.id,
            local_order_id=payment.local_order_id,
            payload=callback_payload,
            success=False,
            external_payment_id=external_payment_id,
            paid_at=None,
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
            if processed_payment is not None and processed_payment.status == PAYMENT_STATUS_PAID:
                self._issued_ticket_service.issue_tickets_for_paid_payment(processed_payment)
            self._payment_repository.db.commit()
        except Exception:
            self._payment_repository.db.rollback()
            raise

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
