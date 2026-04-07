from fastapi import APIRouter, Depends

from ...core.exceptions.schemas import ErrorResponse
from .dependencies import get_admin_auth_service, get_current_admin_user
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
    responses={401: {'model': ErrorResponse}, 503: {'model': ErrorResponse}},
)
def login(
    payload: AdminLoginRequest,
    service: AdminAuthService = Depends(get_admin_auth_service),
) -> AdminAuthResponse:
    return service.login(payload)


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
