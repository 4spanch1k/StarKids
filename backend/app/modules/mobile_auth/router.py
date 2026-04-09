from fastapi import APIRouter, Depends, Response, status

from ...core.exceptions.schemas import ErrorResponse
from .dependencies import (
    get_current_mobile_user,
    get_mobile_access_token,
    get_mobile_auth_service,
)
from .schemas import (
    MobileAuthResponse,
    MobileCurrentUserResponse,
    MobileRefreshRequest,
    OTPRequest,
    OTPRequestResponse,
    OTPVerifyRequest,
)
from .service import MobileAuthService

router = APIRouter()
me_router = APIRouter()


@router.post(
    '/request-otp',
    response_model=OTPRequestResponse,
    responses={422: {'model': ErrorResponse}},
)
def request_otp(
    payload: OTPRequest,
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> OTPRequestResponse:
    return service.request_otp(payload)


@router.post(
    '/verify-otp',
    response_model=MobileAuthResponse,
    responses={
        401: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
        503: {'model': ErrorResponse},
    },
)
def verify_otp(
    payload: OTPVerifyRequest,
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> MobileAuthResponse:
    return service.verify_otp(payload)


@router.post(
    '/refresh',
    response_model=MobileAuthResponse,
    responses={401: {'model': ErrorResponse}, 503: {'model': ErrorResponse}},
)
def refresh(
    payload: MobileRefreshRequest,
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> MobileAuthResponse:
    return service.refresh(payload)


@router.get(
    '/current-user',
    response_model=MobileCurrentUserResponse,
    responses={401: {'model': ErrorResponse}, 503: {'model': ErrorResponse}},
)
@me_router.get(
    '/me',
    response_model=MobileCurrentUserResponse,
    responses={401: {'model': ErrorResponse}, 503: {'model': ErrorResponse}},
)
def current_user(
    current_mobile_user: MobileCurrentUserResponse = Depends(get_current_mobile_user),
) -> MobileCurrentUserResponse:
    return current_mobile_user


@router.post(
    '/logout',
    status_code=status.HTTP_204_NO_CONTENT,
    responses={401: {'model': ErrorResponse}, 503: {'model': ErrorResponse}},
)
def logout(
    access_token: str = Depends(get_mobile_access_token),
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> Response:
    service.logout(access_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
