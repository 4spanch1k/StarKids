from sqlalchemy import select

from ..models.branch import Branch
from ..models.issued_ticket import IssuedTicket
from ..models.mobile_payment import MobilePayment
from ..models.mobile_user import MobileUser
from ..models.ticket_redemption import TicketRedemption
from .base import Repository


class IssuedTicketRepository(Repository):
    def lookup_orders(
        self,
        query: str,
        *,
        branch_id: str | None = None,
    ) -> list[tuple[MobilePayment, MobileUser, Branch | None, list[tuple[IssuedTicket, TicketRedemption | None]]]]:
        normalized = query.strip()
        statement = (
            select(MobilePayment, MobileUser, Branch, IssuedTicket, TicketRedemption)
            .join(MobileUser, MobileUser.id == MobilePayment.mobile_user_id)
            .outerjoin(Branch, Branch.id == MobilePayment.branch_id)
            .outerjoin(IssuedTicket, IssuedTicket.mobile_payment_id == MobilePayment.id)
            .outerjoin(TicketRedemption, TicketRedemption.issued_ticket_id == IssuedTicket.id)
            .where(
                MobilePayment.status == 'paid',
                (MobilePayment.local_order_id == normalized) | (MobileUser.phone == normalized),
            )
            .order_by(MobilePayment.created_at.desc(), IssuedTicket.line_index.asc())
        )
        if branch_id is not None:
            # Scope both sides of the payment -> issued-ticket relation. The
            # payment branch is the order scope, while the ticket branch is
            # the admission authority; requiring both prevents a corrupted
            # or legacy mismatch from leaking another branch's ticket.
            statement = statement.where(
                MobilePayment.branch_id == branch_id,
                IssuedTicket.branch_id == branch_id,
            )
        grouped: dict[str, tuple[MobilePayment, MobileUser, Branch | None, list[tuple[IssuedTicket, TicketRedemption | None]]]] = {}
        for payment, user, branch, ticket, redemption in self.db.execute(statement).all():
            current = grouped.setdefault(payment.id, (payment, user, branch, []))
            if ticket is not None:
                current[3].append((ticket, redemption))
        return list(grouped.values())

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
