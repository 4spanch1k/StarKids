from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator


class LoyaltyAccountResponse(BaseModel):
    balance: int
    reservedBalance: int
    availableBalance: int
    lifetimeEarned: int
    lifetimeSpent: int


class LoyaltyTransactionResponse(BaseModel):
    id: str
    type: str
    amount: int
    balanceDelta: int
    reservedDelta: int
    sourceType: str
    sourceId: str
    status: str
    description: str | None = None
    createdAt: datetime


class LoyaltyTransactionListResponse(BaseModel):
    items: list[LoyaltyTransactionResponse]
    total: int
    limit: int
    offset: int


class LoyaltySettingsResponse(BaseModel):
    maxRedemptionPercent: Decimal
    bonusValueKzt: Decimal


class LoyaltySettingsRequest(BaseModel):
    maxRedemptionPercent: Decimal = Field(ge=0, le=100, max_digits=5, decimal_places=2)
    bonusValueKzt: Decimal = Field(gt=0, max_digits=12, decimal_places=4)


class LoyaltyRuleResponse(BaseModel):
    id: str
    eventType: str
    rewardType: str
    value: Decimal
    isActive: bool
    startsAt: datetime | None = None
    endsAt: datetime | None = None


class LoyaltyRuleRequest(BaseModel):
    eventType: str = Field(min_length=1, max_length=32)
    rewardType: str = Field(min_length=1, max_length=16)
    value: Decimal = Field(ge=0, max_digits=12, decimal_places=4)
    isActive: bool = False
    startsAt: datetime | None = None
    endsAt: datetime | None = None

    @field_validator('eventType')
    @classmethod
    def normalize_event(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator('rewardType')
    @classmethod
    def normalize_reward_type(cls, value: str) -> str:
        return value.strip().lower()


class LoyaltyRuleListResponse(BaseModel):
    items: list[LoyaltyRuleResponse]
