from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.models.mobile_user import MobileUser
from ...db.repositories.mobile_request_history_repository import MobileRequestHistoryRepository
from ...db.repositories.mobile_user_repository import MobileUserRepository
from ..mobile_auth.dependencies import get_mobile_access_token
from ..mobile_auth.service import MobileAuthService
from ..mobile_auth.dependencies import get_mobile_auth_service
from .service import MobileProfileService


def get_mobile_profile_service(
    session: Session = Depends(get_db_session),
) -> MobileProfileService:
    from ...core.config.settings import get_settings
    from ...core.storage.backend import get_storage_backend

    settings = get_settings()
    storage = get_storage_backend(settings)
    return MobileProfileService(
        user_repository=MobileUserRepository(session),
        request_history_repository=MobileRequestHistoryRepository(session),
        storage=storage,
        settings=settings,
    )


def get_authenticated_mobile_user(
    access_token: str = Depends(get_mobile_access_token),
    auth_service: MobileAuthService = Depends(get_mobile_auth_service),
) -> MobileUser:
    return auth_service.authenticate_access_token(access_token)
