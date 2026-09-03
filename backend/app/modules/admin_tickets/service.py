from collections.abc import Callable
from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy.exc import IntegrityError

from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...core.time.business_time import business_today
from ...db.models.admin_user import AdminUser
from ...db.models.branch import Branch
from ...db.models.issued_ticket import IssuedTicket
from ...db.models.ticket_redemption import TicketRedemption
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.issued_ticket_repository import IssuedTicketRepository
from ...db.repositories.ticket_redemption_repository import TicketRedemptionRepository
from ...db.repositories.mobile_payment_repository import MobilePaymentRepository
from ...db.repositories.visit_repository import VisitRepository
from ...db.models.visit import Visit
from ..mobile_payments.ticket_qr_service import TicketQrService
from .schemas import (
    AdminTicketLookupOrder,
    AdminTicketLookupResponse,
    AdminTicketLookupTicket,
    AdminTicketRedemptionResponse,
)


class TicketRedemptionService:
    def __init__(
        self,
        *,
        issued_ticket_repository: IssuedTicketRepository,
        redemption_repository: TicketRedemptionRepository,
        payment_repository: MobilePaymentRepository,
        visit_repository: VisitRepository,
        branch_repository: BranchRepository,
        ticket_qr_service: TicketQrService,
        business_date_provider: Callable[[], date] = business_today,
    ) -> None:
        self._issued_ticket_repository = issued_ticket_repository
        self._redemption_repository = redemption_repository
        self._payment_repository = payment_repository
        self._visit_repository = visit_repository
        self._branch_repository = branch_repository
        self._ticket_qr_service = ticket_qr_service
        self._business_date_provider = business_date_provider

    def redeem(
        self,
        *,
        qr_payload: str,
        branch_id: str,
        admin_user: AdminUser,
    ) -> AdminTicketRedemptionResponse:
        ticket_id = self._ticket_qr_service.verify_payload(qr_payload)
        if ticket_id is None:
            raise DomainHTTPException(
                code='invalid_qr',
                message='QR payload is invalid.',
            )

        ticket = self._issued_ticket_repository.get_by_id_for_update(ticket_id)
        if ticket is None:
            raise NotFoundException(
                code='ticket_not_found',
                message='Ticket was not found.',
            )

        redemption = self._redemption_repository.get_for_ticket(ticket.id)
        if redemption is not None:
            branch = self._branch_repository.get_by_id(ticket.branch_id)
            return self._response(
                outcome='already_used',
                ticket=ticket,
                branch=branch,
                redeemed_at=redemption.redeemed_at,
                visit_id=redemption.visit_id,
            )
        if ticket.status != 'issued':
            raise DomainHTTPException(
                code='invalid_status',
                message='Ticket is not valid for redemption.',
                status_code=409,
            )
        if ticket.branch_id != branch_id:
            raise DomainHTTPException(
                code='wrong_branch',
                message='Ticket belongs to another branch.',
                status_code=409,
            )
        if ticket.visit_date is None:
            raise DomainHTTPException(
                code='invalid_ticket_data',
                message='Ticket visit date is missing.',
                status_code=409,
            )
        if ticket.visit_date != self._business_date_provider():
            raise DomainHTTPException(
                code='wrong_date',
                message='Ticket is not valid for today.',
                status_code=409,
            )

        # Lock the payment/order as well as the individual ticket. This
        # serializes two scanners redeeming different tickets from one order,
        # so both cannot create two Visits for the same family attendance.
        payment = self._payment_repository.get_by_id_for_update(ticket.mobile_payment_id)
        if payment is None or payment.status != 'paid':
            raise DomainHTTPException(
                code='invalid_payment',
                message='Ticket payment is not valid for redemption.',
                status_code=409,
            )

        visit = self._visit_repository.get_for_payment(payment.id, for_update=True)
        if visit is None:
            visit = self._visit_repository.add(
                Visit(
                    id=uuid4().hex,
                    mobile_payment_id=payment.id,
                    mobile_user_id=payment.mobile_user_id,
                    branch_id=ticket.branch_id,
                    status='active',
                    started_at=datetime.now(UTC),
                )
            )

        redeemed_at = datetime.now(UTC)
        redemption = TicketRedemption(
            issued_ticket_id=ticket.id,
            branch_id=ticket.branch_id,
            redeemed_by_admin_user_id=admin_user.id,
            redeemed_at=redeemed_at,
            visit_id=visit.id,
        )
        self._redemption_repository.add(redemption)
        ticket.status = 'used'
        self._issued_ticket_repository.db.add(ticket)
        try:
            self._issued_ticket_repository.db.commit()
        except IntegrityError:
            self._issued_ticket_repository.db.rollback()
            locked_ticket = self._issued_ticket_repository.get_by_id_for_update(ticket.id)
            existing_redemption = self._redemption_repository.get_for_ticket(ticket.id)
            if locked_ticket is not None and existing_redemption is not None:
                return self._response(
                    outcome='already_used',
                    ticket=locked_ticket,
                    branch=self._branch_repository.get_by_id(locked_ticket.branch_id),
                    redeemed_at=existing_redemption.redeemed_at,
                    visit_id=existing_redemption.visit_id,
                )
            raise

        self._issued_ticket_repository.db.refresh(ticket)
        self._issued_ticket_repository.db.refresh(redemption)
        return self._response(
            outcome='redeemed',
            ticket=ticket,
            branch=self._branch_repository.get_by_id(ticket.branch_id),
            redeemed_at=redemption.redeemed_at,
            visit_id=visit.id,
        )

    def lookup(self, query: str) -> AdminTicketLookupResponse:
        items = []
        for payment, user, branch, tickets in self._issued_ticket_repository.lookup_orders(query):
            items.append(
                AdminTicketLookupOrder(
                    paymentId=payment.id,
                    localOrderId=payment.local_order_id,
                    phone=user.phone,
                    branchId=payment.branch_id,
                    branchName=branch.name if branch is not None else 'Boom Bala',
                    visitDate=payment.visit_date,
                    amountTenge=payment.amount_tenge,
                    status=payment.status,
                    tickets=[
                        AdminTicketLookupTicket(
                            ticketId=ticket.id,
                            ticketNumber=ticket.ticket_number,
                            title=ticket.title_snapshot,
                            status=ticket.status,
                            visitDate=ticket.visit_date,
                            redeemedAt=redemption.redeemed_at if redemption else None,
                            visitId=redemption.visit_id if redemption else None,
                        )
                        for ticket, redemption in tickets
                    ],
                )
            )
        return AdminTicketLookupResponse(items=items)

    @staticmethod
    def _response(
        *,
        outcome: str,
        ticket: IssuedTicket,
        branch: Branch | None,
        redeemed_at: datetime | None,
        visit_id: str | None,
    ) -> AdminTicketRedemptionResponse:
        return AdminTicketRedemptionResponse(
            outcome=outcome,
            ticketId=ticket.id,
            ticketNumber=ticket.ticket_number,
            title=ticket.title_snapshot,
            branchId=ticket.branch_id,
            branchName=branch.name if branch is not None else 'Boom Bala',
            visitDate=ticket.visit_date,
            status=ticket.status,
            redeemedAt=redeemed_at,
            visitId=visit_id,
        )
