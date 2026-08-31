from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.config.settings import Settings, get_settings
from ...core.database.session import get_db_session
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.issued_ticket_repository import IssuedTicketRepository
from ...db.repositories.ticket_redemption_repository import TicketRedemptionRepository
from ..mobile_payments.ticket_qr_service import TicketQrService
from .service import TicketRedemptionService


def get_ticket_redemption_service(
    session: Session = Depends(get_db_session),
    settings: Settings = Depends(get_settings),
) -> TicketRedemptionService:
    return TicketRedemptionService(
        issued_ticket_repository=IssuedTicketRepository(session),
        redemption_repository=TicketRedemptionRepository(session),
        branch_repository=BranchRepository(session),
        ticket_qr_service=TicketQrService(settings.ticket_qr_secret),
    )
