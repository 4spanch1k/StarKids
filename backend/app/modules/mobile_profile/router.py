from fastapi import APIRouter, Depends, UploadFile, status

from ...core.exceptions.schemas import ErrorResponse
from ...db.models.mobile_user import MobileUser
from .dependencies import get_authenticated_mobile_user, get_mobile_profile_service
from .schemas import (
    MobileAvatarUploadResponse,
    MobileProfileRequestListResponse,
    MobileProfileResponse,
    MobileProfileUpdateRequest,
)
from .service import MobileProfileService

router = APIRouter()


@router.get(
    '/me',
    response_model=MobileProfileResponse,
    response_model_exclude_none=False,
    responses={401: {'model': ErrorResponse}},
)
def get_profile(
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileProfileService = Depends(get_mobile_profile_service),
) -> MobileProfileResponse:
    return service.get_profile(user)


@router.patch(
    '/me',
    response_model=MobileProfileResponse,
    response_model_exclude_none=False,
    responses={
        401: {'model': ErrorResponse},
        409: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_profile(
    payload: MobileProfileUpdateRequest,
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileProfileService = Depends(get_mobile_profile_service),
) -> MobileProfileResponse:
    return service.update_profile(user, payload)


@router.post(
    '/me/avatar',
    response_model=MobileAvatarUploadResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        401: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
async def upload_avatar(
    file: UploadFile,
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileProfileService = Depends(get_mobile_profile_service),
) -> MobileAvatarUploadResponse:
    content = await file.read()
    content_type = file.content_type or 'application/octet-stream'
    return service.upload_avatar(user, content_type, content)


@router.delete(
    '/me/avatar',
    response_model=MobileProfileResponse,
    responses={401: {'model': ErrorResponse}},
)
def delete_avatar(
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileProfileService = Depends(get_mobile_profile_service),
) -> MobileProfileResponse:
    return service.delete_avatar(user)


@router.get(
    '/me/requests',
    response_model=MobileProfileRequestListResponse,
    responses={401: {'model': ErrorResponse}},
)
def list_requests(
    limit: int = 20,
    offset: int = 0,
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileProfileService = Depends(get_mobile_profile_service),
) -> MobileProfileRequestListResponse:
    return service.list_requests(user.id, limit=limit, offset=offset)
