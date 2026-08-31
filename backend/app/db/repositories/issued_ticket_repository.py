from sqlalchemy import select

from ..models.branch import Branch
from ..models.issued_ticket import IssuedTicket
from ..models.mobile_payment import MobilePayment
from .base import Repository


class IssuedTicketRepository(Repository):
    def list_for_payment(self, payment_id: str) -> list[IssuedTicket]:
        statement = (
            select(IssuedTicket)
            .where(IssuedTicket.mobile_payment_id == payment_id)
            .order_by(IssuedTicket.line_index.asc())
        )
        return list(self.db.scalars(statement).all())

    def list_for_user(self, mobile_user_id: str) -> list[tuple[IssuedTicket, Branch | None]]:
        statement = (
            select(IssuedTicket, Branch)
            .join(MobilePayment, MobilePayment.id == IssuedTicket.mobile_payment_id)
            .outerjoin(Branch, Branch.id == IssuedTicket.branch_id)
            .where(MobilePayment.mobile_user_id == mobile_user_id)
            .order_by(IssuedTicket.issued_at.desc(), IssuedTicket.line_index.asc())
        )
        return list(self.db.execute(statement).all())

    def get_for_user(
        self,
        *,
        ticket_id: str,
        mobile_user_id: str,
    ) -> tuple[IssuedTicket, Branch | None] | None:
        statement = (
            select(IssuedTicket, Branch)
            .join(MobilePayment, MobilePayment.id == IssuedTicket.mobile_payment_id)
            .outerjoin(Branch, Branch.id == IssuedTicket.branch_id)
            .where(
                IssuedTicket.id == ticket_id,
                MobilePayment.mobile_user_id == mobile_user_id,
            )
        )
        return self.db.execute(statement).one_or_none()

    def get_by_id_for_update(self, ticket_id: str) -> IssuedTicket | None:
        statement = select(IssuedTicket).where(IssuedTicket.id == ticket_id).with_for_update()
        return self.db.scalar(statement)

    def add(self, ticket: IssuedTicket) -> IssuedTicket:
        self.db.add(ticket)
        return ticket
