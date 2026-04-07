from collections.abc import Callable

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.repositories.admin_session_repository import AdminSessionRepository
from ...db.repositories.admin_user_repository import AdminUserRepository
from .schemas import AdminCurrentUserResponse
from .service import AdminAuthService

bearer_scheme = HTTPBearer(auto_error=False)


def get_admin_auth_service(
    session: Session = Depends(get_db_session),
) -> AdminAuthService:
    return AdminAuthService(
        user_repository=AdminUserRepository(session),
        session_repository=AdminSessionRepository(session),
    )


def get_current_admin_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    service: AdminAuthService = Depends(get_admin_auth_service),
) -> AdminCurrentUserResponse:
    if credentials is None or credentials.scheme.lower() != 'bearer':
        raise AdminAuthService.authentication_required_exception()
    return service.get_current_user(credentials.credentials)


def require_admin_roles(
    *allowed_roles: str,
) -> Callable[[AdminCurrentUserResponse], AdminCurrentUserResponse]:
    def dependency(
        current_user: AdminCurrentUserResponse = Depends(get_current_admin_user),
    ) -> AdminCurrentUserResponse:
        if current_user.role not in allowed_roles:
            raise AdminAuthService.authorization_required_exception()
        return current_user

    return dependency
