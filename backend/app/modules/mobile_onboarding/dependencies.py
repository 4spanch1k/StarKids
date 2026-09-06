from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ..mobile_auth.dependencies import (
    AuthenticatedMobileContext,
    get_current_mobile_auth_context,
)
from .service import MobileOnboardingService


def get_mobile_onboarding_service(
    session: Session = Depends(get_db_session),
) -> MobileOnboardingService:
    return MobileOnboardingService(session=session)


def get_authenticated_onboarding_context(
    context: AuthenticatedMobileContext = Depends(get_current_mobile_auth_context),
) -> AuthenticatedMobileContext:
    return context
