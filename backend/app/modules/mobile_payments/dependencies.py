from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.config.settings import Settings, get_settings
from ...core.database.session import get_db_session
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.branch_ticket_repository import BranchTicketRepository
from ...db.repositories.issued_ticket_repository import IssuedTicketRepository
from ...db.repositories.mobile_payment_repository import MobilePaymentRepository
from .freedompay_client import FreedomPayClient, FreedomPayClientProtocol
from .issued_ticket_service import IssuedTicketService
from .ticket_qr_service import TicketQrService
from .service import MobilePaymentService


def get_freedompay_client(settings: Settings = Depends(get_settings)) -> FreedomPayClientProtocol:
    return FreedomPayClient(settings)


def get_mobile_payment_service(
    session: Session = Depends(get_db_session),
    settings: Settings = Depends(get_settings),
    freedompay_client: FreedomPayClientProtocol = Depends(get_freedompay_client),
) -> MobilePaymentService:
    return MobilePaymentService(
        settings=settings,
        payment_repository=MobilePaymentRepository(session),
        branch_repository=BranchRepository(session),
        ticket_repository=BranchTicketRepository(session),
        freedompay_client=freedompay_client,
        issued_ticket_service=IssuedTicketService(IssuedTicketRepository(session)),
        ticket_qr_service=TicketQrService(settings.ticket_qr_secret or ''),
    )
