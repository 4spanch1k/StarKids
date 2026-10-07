from datetime import date

from sqlalchemy import select

from ..models.pass_redemption import PassRedemption
from .base import Repository


class PassRedemptionRepository(Repository):
    def get_for_pass_date(self, pass_id: str, business_date: date, *, for_update: bool = False) -> PassRedemption | None:
        statement = select(PassRedemption).where(
            PassRedemption.customer_pass_id == pass_id,
            PassRedemption.business_date == business_date,
        )
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def add(self, redemption: PassRedemption) -> PassRedemption:
        self.db.add(redemption)
        return redemption
