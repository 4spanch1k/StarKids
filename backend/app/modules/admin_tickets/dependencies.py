from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.config.settings import Settings, get_settings
from ...core.database.session import get_db_session
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.issued_ticket_repository import IssuedTicketRepository
from ...db.repositories.ticket_redemption_repository import TicketRedemptionRepository
from ...db.repositories.mobile_payment_repository import MobilePaymentRepository
from ...db.repositories.mobile_user_repository import MobileUserRepository
from ...db.repositories.loyalty_repository import LoyaltyRepository
from ...db.repositories.visit_repository import VisitRepository
from ..mobile_payments.ticket_qr_service import TicketQrService
from ..mobile_profile.customer_qr_service import CustomerQrService
from .customer_identification_service import CustomerIdentificationService
from .service import TicketRedemptionService


def get_ticket_redemption_service(
    session: Session = Depends(get_db_session),
    settings: Settings = Depends(get_settings),
) -> TicketRedemptionService:
    return TicketRedemptionService(
        issued_ticket_repository=IssuedTicketRepository(session),
        redemption_repository=TicketRedemptionRepository(session),
        payment_repository=MobilePaymentRepository(session),
        visit_repository=VisitRepository(session),
        branch_repository=BranchRepository(session),
        ticket_qr_service=TicketQrService(settings.ticket_qr_secret),
    )


def get_customer_identification_service(
    session: Session = Depends(get_db_session),
    settings: Settings = Depends(get_settings),
) -> CustomerIdentificationService:
    return CustomerIdentificationService(
        user_repository=MobileUserRepository(session),
        loyalty_repository=LoyaltyRepository(session),
        branch_repository=BranchRepository(session),
        customer_qr_service=CustomerQrService(settings.ticket_qr_secret),
    )
