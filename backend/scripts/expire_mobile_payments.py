"""Release loyalty reservations for abandoned mobile ticket payments.

Run this script from the backend directory on a small periodic schedule. The
mobile status/init endpoints also reconcile lazily, but the scheduled pass
prevents abandoned reservations from remaining locked when a customer never
opens the app again and retries paid loyalty settlement after a transient
loyalty failure.
"""

from app.core.config.settings import get_settings
from app.core.database.session import SessionLocal
from app.db.repositories.branch_repository import BranchRepository
from app.db.repositories.branch_ticket_repository import BranchTicketRepository
from app.db.repositories.issued_ticket_repository import IssuedTicketRepository
from app.db.repositories.loyalty_repository import LoyaltyRepository
from app.db.repositories.mobile_payment_repository import MobilePaymentRepository
from app.db.repositories.visit_repository import VisitRepository
from app.modules.loyalty.service import LoyaltyService
from app.modules.mobile_payments.dependencies import get_freedompay_client
from app.modules.mobile_payments.issued_ticket_service import IssuedTicketService
from app.modules.mobile_payments.service import MobilePaymentService
from app.modules.mobile_payments.ticket_qr_service import TicketQrService


def main() -> None:
    settings = get_settings()
    session = SessionLocal()
    try:
        service = MobilePaymentService(
            settings=settings,
            payment_repository=MobilePaymentRepository(session),
            branch_repository=BranchRepository(session),
            ticket_repository=BranchTicketRepository(session),
            freedompay_client=get_freedompay_client(settings),
            issued_ticket_service=IssuedTicketService(IssuedTicketRepository(session)),
            ticket_qr_service=TicketQrService(settings.ticket_qr_secret or ''),
            visit_repository=VisitRepository(session),
            loyalty_service=LoyaltyService(LoyaltyRepository(session)),
        )
        print(f'expired mobile payments: {service.expire_stale_payments()}')
        print(f'reconciled paid payments: {service.settle_paid_loyalty()}')
    finally:
        session.close()


if __name__ == '__main__':
    main()
