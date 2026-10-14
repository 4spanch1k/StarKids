from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.config.settings import Settings, get_settings
from ...core.database.session import get_db_session
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.customer_pass_repository import CustomerPassRepository
from ...db.repositories.mobile_child_repository import MobileChildRepository
from ...db.repositories.pass_plan_repository import PassPlanRepository
from ...db.repositories.pass_redemption_repository import PassRedemptionRepository
from ...db.repositories.visit_repository import VisitRepository
from .qr_service import PassQrService
from .service import PassService


def get_pass_service(
    session: Session = Depends(get_db_session),
    settings: Settings = Depends(get_settings),
) -> PassService:
    return PassService(
        plan_repository=PassPlanRepository(session),
        customer_pass_repository=CustomerPassRepository(session),
        redemption_repository=PassRedemptionRepository(session),
        child_repository=MobileChildRepository(session),
        branch_repository=BranchRepository(session),
        visit_repository=VisitRepository(session),
        qr_service=PassQrService(settings.ticket_qr_secret),
    )
