from __future__ import annotations

from sqlalchemy import select

from ...db.models.branch import Branch
from ...db.models.mobile_payment import MobilePayment
from ...db.models.mobile_payment_callback import MobilePaymentCallback
from ...db.models.mobile_user import MobileUser
from ...db.repositories.base import Repository


class AdminReconciliationRepository(Repository):
    def list_items(self) -> list[tuple[MobilePayment, MobileUser, Branch | None, list[MobilePaymentCallback]]]:
        pending = list(
            self.db.scalars(
                select(MobilePayment)
                .where(
                    MobilePayment.ticket_issuance_required.is_(True)
                    | MobilePayment.loyalty_settlement_required.is_(True)
                    | MobilePayment.pass_issuance_required.is_(True)
                )
                .order_by(MobilePayment.created_at.asc(), MobilePayment.id.asc())
            )
        )
        grouped: dict[str, tuple[MobilePayment, MobileUser, Branch | None, list[MobilePaymentCallback]]] = {}
        for payment in pending:
            user = self.db.get(MobileUser, payment.mobile_user_id)
            branch = self.db.get(Branch, payment.branch_id)
            if user is not None:
                grouped[payment.id] = (payment, user, branch, [])

        callback_rows = self.db.execute(
            select(MobilePaymentCallback, MobilePayment, MobileUser, Branch)
            .join(MobilePayment, MobilePayment.id == MobilePaymentCallback.mobile_payment_id)
            .join(MobileUser, MobileUser.id == MobilePayment.mobile_user_id)
            .outerjoin(Branch, Branch.id == MobilePayment.branch_id)
            .where(MobilePaymentCallback.result == 'reconciliation_required')
            .order_by(MobilePaymentCallback.received_at.asc(), MobilePaymentCallback.id.asc())
        ).all()
        for callback, payment, user, branch in callback_rows:
            current = grouped.get(payment.id)
            if current is None:
                current = (payment, user, branch, [])
                grouped[payment.id] = current
            current[3].append(callback)
        return list(grouped.values())
