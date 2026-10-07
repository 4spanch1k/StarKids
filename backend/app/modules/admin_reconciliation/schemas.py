from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class ReconciliationItem(BaseModel):
    paymentId: str
    localOrderId: str
    createdAt: datetime
    paidAt: datetime | None
    branchId: str
    branchName: str
    customer: str
    amountTenge: int
    issueType: str
    lastFailure: str | None
    ticketIssuancePending: bool
    loyaltySettlementPending: bool
    passIssuancePending: bool = False
    callbackMismatch: bool


class ReconciliationResponse(BaseModel):
    items: list[ReconciliationItem]
    total: int
