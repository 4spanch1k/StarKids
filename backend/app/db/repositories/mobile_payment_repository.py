from datetime import UTC, date, datetime
import hashlib
import json

from sqlalchemy import select

from ..models.branch import Branch
from ..models.mobile_payment import MobilePayment
from ..models.mobile_payment_callback import MobilePaymentCallback
from ...modules.mobile_payments.constants import TERMINAL_PAYMENT_STATUSES
from .base import Repository


class MobilePaymentRepository(Repository):
    def create_ticket_payment(
        self,
        *,
        mobile_user_id: str,
        branch_id: str,
        payable_entity_type: str,
        payable_entity_id: str,
        local_order_id: str,
        idempotency_key: str,
        amount_tenge: int,
        currency: str,
        quantity: int,
        visit_date: date | None,
        ticket_items: list[dict[str, object]],
        init_payload: dict[str, object],
    ) -> MobilePayment:
        payment = MobilePayment(
            mobile_user_id=mobile_user_id,
            branch_id=branch_id,
            payable_entity_type=payable_entity_type,
            payable_entity_id=payable_entity_id,
            local_order_id=local_order_id,
            idempotency_key=idempotency_key,
            amount_tenge=amount_tenge,
            currency=currency,
            quantity=quantity,
            visit_date=visit_date,
            ticket_items=ticket_items,
            status='created',
            init_payload=init_payload,
        )
        self.db.add(payment)
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def get_by_idempotency_key_for_user(
        self,
        *,
        mobile_user_id: str,
        idempotency_key: str,
        for_update: bool = False,
    ) -> MobilePayment | None:
        statement = select(MobilePayment).where(
            MobilePayment.mobile_user_id == mobile_user_id,
            MobilePayment.idempotency_key == idempotency_key,
        )
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def get_by_id(self, payment_id: str) -> MobilePayment | None:
        return self.db.scalar(select(MobilePayment).where(MobilePayment.id == payment_id))

    def get_by_id_for_user(
        self,
        *,
        payment_id: str,
        mobile_user_id: str,
    ) -> MobilePayment | None:
        statement = select(MobilePayment).where(
            MobilePayment.id == payment_id,
            MobilePayment.mobile_user_id == mobile_user_id,
        )
        return self.db.scalar(statement)

    def get_by_local_order_id(self, local_order_id: str) -> MobilePayment | None:
        statement = select(MobilePayment).where(MobilePayment.local_order_id == local_order_id)
        return self.db.scalar(statement)

    def mark_pending(
        self,
        payment: MobilePayment,
        *,
        external_payment_id: str,
        init_payload: dict[str, object],
        payment_url: str | None = None,
    ) -> MobilePayment:
        if payment.status in TERMINAL_PAYMENT_STATUSES:
            return payment
        payment.external_payment_id = external_payment_id
        payment.payment_url = payment_url
        payment.init_payload = init_payload
        payment.status = 'pending'
        payment.failure_reason = None
        self.db.add(payment)
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def mark_failed(
        self,
        payment: MobilePayment,
        *,
        status: str,
        callback_payload: dict[str, object],
        failure_reason: str,
    ) -> MobilePayment:
        if payment.status in TERMINAL_PAYMENT_STATUSES:
            return payment
        payment.status = status
        payment.callback_payload = callback_payload
        payment.failure_reason = failure_reason
        self.db.add(payment)
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def record_rejected_callback(
        self,
        *,
        payment_id: str,
        local_order_id: str,
        payload: dict[str, object],
        reason: str,
        audit_result: str = 'rejected',
    ) -> MobilePayment | None:
        return self._process_callback(
            payment_id=payment_id,
            local_order_id=local_order_id,
            payload=payload,
            result=audit_result,
            failure_reason=reason,
            deduplicate_provider_event=False,
        )

    def process_not_completed_callback(
        self,
        *,
        payment_id: str,
        local_order_id: str,
        payload: dict[str, object],
    ) -> MobilePayment | None:
        return self._process_callback(
            payment_id=payment_id,
            local_order_id=local_order_id,
            payload=payload,
            result='not_completed',
            failure_reason=None,
        )

    def process_verified_callback(
        self,
        *,
        payment_id: str,
        local_order_id: str,
        payload: dict[str, object],
        success: bool,
        external_payment_id: str | None,
        paid_at: datetime | None,
        failure_status: str | None,
        failure_reason: str | None,
        commit: bool = True,
    ) -> MobilePayment | None:
        return self._process_callback(
            payment_id=payment_id,
            local_order_id=local_order_id,
            payload=payload,
            result='success' if success else 'failure',
            external_payment_id=external_payment_id,
            paid_at=paid_at,
            failure_status=failure_status,
            failure_reason=failure_reason,
            commit=commit,
        )

    def _process_callback(
        self,
        *,
        payment_id: str,
        local_order_id: str,
        payload: dict[str, object],
        result: str,
        external_payment_id: str | None = None,
        paid_at: datetime | None = None,
        failure_status: str | None = None,
        failure_reason: str | None = None,
        deduplicate_provider_event: bool = True,
        commit: bool = True,
    ) -> MobilePayment | None:
        payment = self.db.scalar(
            select(MobilePayment)
            .where(
                MobilePayment.id == payment_id,
                MobilePayment.local_order_id == local_order_id,
            )
            .with_for_update()
        )
        if payment is None:
            return None

        fingerprint = _callback_fingerprint(payload)
        provider_event_id = _provider_event_id(payload)
        callback = None
        if deduplicate_provider_event and provider_event_id:
            callback = self.db.scalar(
                select(MobilePaymentCallback)
                .where(
                    MobilePaymentCallback.mobile_payment_id == payment.id,
                    MobilePaymentCallback.provider_event_id == provider_event_id,
                )
                .with_for_update()
            )
            if callback is not None and (
                callback.result in {'rejected', 'reconciliation_required'}
                or callback.payload.get('pg_result') != payload.get('pg_result')
            ):
                callback = None
        if callback is None:
            callback = self.db.scalar(
                select(MobilePaymentCallback)
                .where(MobilePaymentCallback.payload_fingerprint == fingerprint)
                .with_for_update()
            )
        if callback is not None:
            callback.duplicate_count += 1
            if commit:
                self.db.commit()
                self.db.refresh(payment)
            else:
                self.db.flush()
            return payment

        status_before = payment.status
        status_after = status_before
        audit_result = result
        if status_before in TERMINAL_PAYMENT_STATUSES and result not in {
            'not_completed',
            'reconciliation_required',
        }:
            audit_result = 'ignored_terminal'
        elif result == 'success':
            status_after = 'paid'
            payment.status = 'paid'
            payment.external_payment_id = external_payment_id or payment.external_payment_id
            payment.callback_payload = payload
            payment.paid_at = paid_at or datetime.now(UTC)
            payment.failure_reason = None
        elif result == 'failure' and failure_status:
            status_after = failure_status
            payment.status = failure_status
            payment.callback_payload = payload
            payment.failure_reason = failure_reason
        elif result == 'not_completed':
            payment.callback_payload = payload
            payment.failure_reason = None

        self.db.add(
            MobilePaymentCallback(
                mobile_payment_id=payment.id,
                local_order_id=payment.local_order_id,
                provider_event_id=provider_event_id,
                payload_fingerprint=fingerprint,
                payload=payload,
                result=audit_result,
                status_before=status_before,
                status_after=status_after,
                failure_reason=failure_reason,
            )
        )
        self.db.add(payment)
        if commit:
            self.db.commit()
            self.db.refresh(payment)
        else:
            self.db.flush()
        return payment

    def mark_paid(
        self,
        payment: MobilePayment,
        *,
        external_payment_id: str | None,
        callback_payload: dict[str, object],
        paid_at: datetime | None,
    ) -> MobilePayment:
        return self.process_verified_callback(
            payment_id=payment.id,
            local_order_id=payment.local_order_id,
            payload=callback_payload,
            success=True,
            external_payment_id=external_payment_id,
            paid_at=paid_at,
            failure_status=None,
            failure_reason=None,
        ) or payment

    def list_paid_ticket_payments_for_user(
        self,
        mobile_user_id: str,
    ) -> list[tuple[MobilePayment, Branch | None]]:
        statement = (
            select(MobilePayment, Branch)
            .outerjoin(Branch, Branch.id == MobilePayment.branch_id)
            .where(
                MobilePayment.mobile_user_id == mobile_user_id,
                MobilePayment.payable_entity_type == 'branch_ticket_order',
                MobilePayment.status == 'paid',
            )
            .order_by(MobilePayment.paid_at.desc(), MobilePayment.created_at.desc())
        )
        return list(self.db.execute(statement).all())


def _callback_fingerprint(payload: dict[str, object]) -> str:
    canonical_payload = json.dumps(
        payload,
        sort_keys=True,
        separators=(',', ':'),
        ensure_ascii=True,
        default=str,
    )
    return hashlib.sha256(canonical_payload.encode('utf-8')).hexdigest()


def _provider_event_id(payload: dict[str, object]) -> str | None:
    raw_event_id = payload.get('pg_payment_id')
    if raw_event_id is None:
        return None
    event_id = str(raw_event_id).strip()
    return event_id or None
