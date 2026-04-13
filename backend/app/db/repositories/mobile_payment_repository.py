from datetime import UTC, date, datetime

from sqlalchemy import select

from ..models.branch import Branch
from ..models.mobile_payment import MobilePayment
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
    ) -> MobilePayment:
        payment.external_payment_id = external_payment_id
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
        if payment.status == 'paid':
            return payment
        payment.status = status
        payment.callback_payload = callback_payload
        payment.failure_reason = failure_reason
        self.db.add(payment)
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def mark_paid(
        self,
        payment: MobilePayment,
        *,
        external_payment_id: str | None,
        callback_payload: dict[str, object],
        paid_at: datetime | None,
    ) -> MobilePayment:
        if payment.status == 'paid':
            return payment

        confirmed_at = paid_at or datetime.now(UTC)
        if external_payment_id:
            payment.external_payment_id = external_payment_id
        payment.status = 'paid'
        payment.callback_payload = callback_payload
        payment.paid_at = confirmed_at
        payment.failure_reason = None
        if payment.issued_at is None:
            payment.issued_at = confirmed_at
        self.db.add(payment)
        self.db.commit()
        self.db.refresh(payment)
        return payment

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
