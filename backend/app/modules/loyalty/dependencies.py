from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.repositories.loyalty_repository import LoyaltyRepository
from .service import LoyaltyService


def get_loyalty_service(session: Session = Depends(get_db_session)) -> LoyaltyService:
    return LoyaltyService(LoyaltyRepository(session))
