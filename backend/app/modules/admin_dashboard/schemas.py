from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, field_serializer


class OwnerDashboardPeriod(str, Enum):
    TODAY = 'today'
    SEVEN_DAYS = '7d'
    THIRTY_DAYS = '30d'


class OwnerDashboardResponse(BaseModel):
    period: OwnerDashboardPeriod
    periodStart: datetime
    periodEnd: datetime
    timezone: str
    ticketCashCollectedTenge: int
    paidTicketPurchases: int
    ticketsSold: int
    visits: int
    newFamilies: int
    returningFamilies: int
    bonusesIssued: int
    bonusesRedeemed: int
    outstandingBonusBalance: int

    @field_serializer('periodStart', 'periodEnd')
    def serialize_datetime(self, value: datetime) -> str:
        return value.isoformat()
