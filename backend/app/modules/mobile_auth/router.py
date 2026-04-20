from fastapi import APIRouter, Depends, Response, status

from ...core.exceptions.schemas import ErrorResponse
from ..auth_security.dependencies import AuthRequestContext, get_auth_request_context
from .dependencies import (
    get_current_mobile_user,
    get_mobile_access_token,
    get_mobile_auth_service,
)
from .schemas import (
    MobileAuthResponse,
    MobileCurrentUserResponse,
    MobileEmailLoginRequest,
    MobileEmailRegistrationRequest,
    MobileRefreshRequest,
    OTPRequest,
    OTPRequestResponse,
    OTPVerifyRequest,
)
from .service import MobileAuthService

router = APIRouter()


@router.post(
    '/register',
    response_model=MobileAuthResponse,
    response_model_exclude_none=True,
    responses={
        409: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
        503: {'model': ErrorResponse},
    },
)
def register(
    payload: MobileEmailRegistrationRequest,
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> MobileAuthResponse:
    return service.register_with_email(payload)


@router.post(
    '/login',
    response_model=MobileAuthResponse,
    response_model_exclude_none=True,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        429: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
        503: {'model': ErrorResponse},
    },
)
def login(
    payload: MobileEmailLoginRequest,
    context: AuthRequestContext = Depends(get_auth_request_context),
    service: MobileAuthService = Depends(get_mobile_auth_service),
) -> MobileAuthResponse:
    return service.login_with_email(payload, context=context)


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
    response_model_exclude_none=True,
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
    response_model_exclude_none=True,
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
    response_model_exclude_none=True,
    responses={401: {'model': ErrorResponse}, 503: {'model': ErrorResponse}},
)
@router.get(
    '/me',
    response_model=MobileCurrentUserResponse,
    response_model_exclude_none=True,
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
