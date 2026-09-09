from datetime import UTC, datetime
from secrets import token_hex

from sqlalchemy import select

from ...db.models.branch import Branch
from ...db.models.issued_ticket import IssuedTicket
from ...db.models.mobile_payment import MobilePayment
from ...db.repositories.issued_ticket_repository import IssuedTicketRepository


class IssuedTicketService:
    def __init__(self, repository: IssuedTicketRepository) -> None:
        self._repository = repository

    def issue_tickets_for_paid_payment(self, payment: MobilePayment) -> list[IssuedTicket]:
        locked_payment = self._repository.db.scalar(
            select(MobilePayment)
            .where(MobilePayment.id == payment.id)
            .with_for_update()
        )
        if locked_payment is None or locked_payment.status != 'paid':
            return []

        expected_lines: list[dict[str, object]] = []
        for item in locked_payment.ticket_items:
            quantity = int(item.get('quantity') or 0)
            if quantity < 0:
                raise ValueError('Payment ticket snapshot contains a negative quantity.')
            for _ in range(quantity):
                expected_lines.append(item)

        if len(expected_lines) != locked_payment.quantity:
            raise ValueError('Payment ticket snapshot quantity does not match payment quantity.')

        existing_tickets = {
            ticket.line_index: ticket
            for ticket in self._repository.list_for_payment(locked_payment.id)
        }
        issued_at = datetime.now(UTC)
        for line_index, item in enumerate(expected_lines):
            if line_index in existing_tickets:
                continue
            ticket = IssuedTicket(
                mobile_payment_id=locked_payment.id,
                ticket_number=self._new_ticket_number(),
                ticket_item_id=str(item.get('ticketItemId') or ''),
                title_snapshot=str(item.get('title') or 'Билет'),
                price_tenge=int(item.get('priceTenge') or 0),
                branch_id=locked_payment.branch_id,
                visit_date=locked_payment.visit_date,
                line_index=line_index,
                status='issued',
                issued_at=issued_at,
            )
            self._repository.add(ticket)
            existing_tickets[line_index] = ticket

        self._repository.db.flush()
        return [existing_tickets[index] for index in range(len(expected_lines))]

    def list_for_user(self, mobile_user_id: str) -> list[tuple[IssuedTicket, Branch | None]]:
        return self._repository.list_for_user(mobile_user_id)

    def get_for_user(
        self,
        *,
        ticket_id: str,
        mobile_user_id: str,
    ) -> tuple[IssuedTicket, Branch | None] | None:
        return self._repository.get_for_user(
            ticket_id=ticket_id,
            mobile_user_id=mobile_user_id,
        )

    @staticmethod
    def _new_ticket_number() -> str:
        return f'BB-{token_hex(5).upper()}'
