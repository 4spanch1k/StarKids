from .repository import AdminReconciliationRepository
from .schemas import ReconciliationItem, ReconciliationResponse


class AdminReconciliationService:
    def __init__(self, *, repository: AdminReconciliationRepository) -> None:
        self.repository = repository

    def list_items(self) -> ReconciliationResponse:
        items: list[ReconciliationItem] = []
        for payment, user, branch, callbacks in self.repository.list_items():
            callback_mismatch = bool(callbacks)
            issue_type = (
                'callback_validation_mismatch'
                if callback_mismatch
                else 'ticket_issuance_pending'
                if payment.ticket_issuance_required
                else 'pass_issuance_pending'
                if getattr(payment, 'pass_issuance_required', False)
                else 'loyalty_settlement_pending'
            )
            last_failure = payment.failure_reason
            if callbacks and callbacks[-1].failure_reason:
                last_failure = callbacks[-1].failure_reason
            items.append(
                ReconciliationItem(
                    paymentId=payment.id,
                    localOrderId=payment.local_order_id,
                    createdAt=payment.created_at,
                    paidAt=payment.paid_at,
                    branchId=payment.branch_id,
                    branchName=branch.name if branch is not None else 'Boom Bala',
                    customer=user.phone or user.email or user.id,
                    amountTenge=payment.amount_tenge,
                    issueType=issue_type,
                    lastFailure=last_failure,
                    ticketIssuancePending=payment.ticket_issuance_required,
                    loyaltySettlementPending=payment.loyalty_settlement_required,
                    passIssuancePending=getattr(payment, 'pass_issuance_required', False),
                    callbackMismatch=callback_mismatch,
                )
            )
        return ReconciliationResponse(items=items, total=len(items))
