from fastapi import APIRouter, Depends, Response, status

from ...core.exceptions.schemas import ErrorResponse
from ..auth_security.dependencies import AuthRequestContext, get_auth_request_context
from .dependencies import (
    get_admin_access_token,
    get_admin_auth_service,
    get_current_admin_user,
)
from .schemas import (
    AdminAuthResponse,
    AdminCurrentUserResponse,
    AdminLoginRequest,
    AdminRefreshRequest,
)
from .service import AdminAuthService

router = APIRouter()


@router.post(
    '/login',
    response_model=AdminAuthResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        429: {'model': ErrorResponse},
        503: {'model': ErrorResponse},
    },
)
def login(
    payload: AdminLoginRequest,
    context: AuthRequestContext = Depends(get_auth_request_context),
    service: AdminAuthService = Depends(get_admin_auth_service),
) -> AdminAuthResponse:
    return service.login(payload, context=context)


@router.post(
    '/refresh',
    response_model=AdminAuthResponse,
    responses={401: {'model': ErrorResponse}, 503: {'model': ErrorResponse}},
)
def refresh(
    payload: AdminRefreshRequest,
    service: AdminAuthService = Depends(get_admin_auth_service),
) -> AdminAuthResponse:
    return service.refresh(payload)


@router.get(
    '/current-user',
    response_model=AdminCurrentUserResponse,
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}},
)
def current_user(
    current_admin_user: AdminCurrentUserResponse = Depends(get_current_admin_user),
) -> AdminCurrentUserResponse:
    return current_admin_user


@router.post(
    '/logout',
    status_code=status.HTTP_204_NO_CONTENT,
    responses={401: {'model': ErrorResponse}, 503: {'model': ErrorResponse}},
)
def logout(
    access_token: str = Depends(get_admin_access_token),
    service: AdminAuthService = Depends(get_admin_auth_service),
) -> Response:
    service.logout(access_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
