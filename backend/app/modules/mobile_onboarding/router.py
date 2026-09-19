from fastapi import APIRouter, Depends, status

from ...core.exceptions.schemas import ErrorResponse
from ..mobile_auth.dependencies import AuthenticatedMobileContext
from .dependencies import (
    get_authenticated_onboarding_context,
    get_mobile_onboarding_service,
)
from .schemas import OnboardingCompleteRequest, OnboardingCompleteResponse
from .service import MobileOnboardingService

router = APIRouter()


@router.post(
    '/complete',
    response_model=OnboardingCompleteResponse,
    status_code=status.HTTP_200_OK,
    responses={
        401: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def complete_onboarding(
    payload: OnboardingCompleteRequest,
    context: AuthenticatedMobileContext = Depends(get_authenticated_onboarding_context),
    service: MobileOnboardingService = Depends(get_mobile_onboarding_service),
) -> OnboardingCompleteResponse:
    return service.complete(user=context.user, payload=payload)
