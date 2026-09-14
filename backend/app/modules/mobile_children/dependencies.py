from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.models.mobile_user import MobileUser
from ...db.repositories.mobile_child_repository import MobileChildRepository
from ..mobile_auth.dependencies import get_mobile_access_token, get_mobile_auth_service
from ..mobile_auth.service import MobileAuthService
from .service import MobileChildrenService


def get_mobile_children_service(
    session: Session = Depends(get_db_session),
) -> MobileChildrenService:
    return MobileChildrenService(child_repository=MobileChildRepository(session))


def get_authenticated_mobile_user(
    access_token: str = Depends(get_mobile_access_token),
    auth_service: MobileAuthService = Depends(get_mobile_auth_service),
) -> MobileUser:
    return auth_service.authenticate_access_token(access_token)
