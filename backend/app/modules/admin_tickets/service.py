from collections.abc import Callable
from datetime import UTC, date, datetime

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
from ..mobile_payments.ticket_qr_service import TicketQrService
from .schemas import AdminTicketRedemptionResponse


class TicketRedemptionService:
    def __init__(
        self,
        *,
        issued_ticket_repository: IssuedTicketRepository,
        redemption_repository: TicketRedemptionRepository,
        branch_repository: BranchRepository,
        ticket_qr_service: TicketQrService,
        business_date_provider: Callable[[], date] = business_today,
    ) -> None:
        self._issued_ticket_repository = issued_ticket_repository
        self._redemption_repository = redemption_repository
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

        redeemed_at = datetime.now(UTC)
        redemption = TicketRedemption(
            issued_ticket_id=ticket.id,
            branch_id=ticket.branch_id,
            redeemed_by_admin_user_id=admin_user.id,
            redeemed_at=redeemed_at,
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
                )
            raise

        self._issued_ticket_repository.db.refresh(ticket)
        self._issued_ticket_repository.db.refresh(redemption)
        return self._response(
            outcome='redeemed',
            ticket=ticket,
            branch=self._branch_repository.get_by_id(ticket.branch_id),
            redeemed_at=redemption.redeemed_at,
        )

    @staticmethod
    def _response(
        *,
        outcome: str,
        ticket: IssuedTicket,
        branch: Branch | None,
        redeemed_at: datetime | None,
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
        )
