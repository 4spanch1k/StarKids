from dataclasses import dataclass

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.models.mobile_session import MobileSession
from ...db.models.mobile_user import MobileUser
from ...db.repositories.auth_throttle_state_repository import AuthThrottleStateRepository
from ...db.repositories.mobile_session_repository import MobileSessionRepository
from ...db.repositories.mobile_user_repository import MobileUserRepository
from ..auth_security.service import AuthProtectionService
from ...core.config.settings import Settings, get_settings
from .clerk_verifier import ClerkSessionVerifier
from .schemas import MobileCurrentUserResponse
from .service import MobileAuthService

bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthenticatedMobileContext:
    user: MobileUser
    session: MobileSession


def get_mobile_auth_service(
    session: Session = Depends(get_db_session),
) -> MobileAuthService:
    return MobileAuthService(
        user_repository=MobileUserRepository(session),
        session_repository=MobileSessionRepository(session),
        auth_protection_service=AuthProtectionService(
            throttle_repository=AuthThrottleStateRepository(session),
        ),
    )


def get_clerk_session_verifier(
    settings: Settings = Depends(get_settings),
) -> ClerkSessionVerifier:
    return ClerkSessionVerifier(settings=settings)


def get_mobile_access_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> str:
    if credentials is None or credentials.scheme.lower() != 'bearer':
        raise MobileAuthService.authentication_required_exception()
    return credentials.credentials


def get_current_mobile_user(
    access_token: str = Depends(get_mobile_access_token),
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> MobileCurrentUserResponse:
    return service.get_current_user(access_token)


def get_current_mobile_auth_context(
    access_token: str = Depends(get_mobile_access_token),
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> AuthenticatedMobileContext:
    user, session = service.authenticate_access_context(access_token)
    return AuthenticatedMobileContext(user=user, session=session)


def get_optional_authenticated_mobile_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> MobileUser | None:
    if credentials is None:
        return None
    if credentials.scheme.lower() != 'bearer':
        raise MobileAuthService.authentication_required_exception()
    return service.authenticate_access_token(credentials.credentials)
