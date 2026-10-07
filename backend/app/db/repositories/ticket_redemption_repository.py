from sqlalchemy import select

from ..models.ticket_redemption import TicketRedemption
from .base import Repository


class TicketRedemptionRepository(Repository):
    def get_for_ticket(
        self,
        issued_ticket_id: str,
        *,
        for_update: bool = False,
    ) -> TicketRedemption | None:
        statement = select(TicketRedemption).where(
            TicketRedemption.issued_ticket_id == issued_ticket_id
        )
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def add(self, redemption: TicketRedemption) -> TicketRedemption:
        self.db.add(redemption)
        return redemption
