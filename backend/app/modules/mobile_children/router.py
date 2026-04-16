from fastapi import APIRouter, Depends, status

from ...core.exceptions.schemas import ErrorResponse
from ...db.models.mobile_user import MobileUser
from .dependencies import get_authenticated_mobile_user, get_mobile_children_service
from .schemas import (
    ChildCreateRequest,
    ChildListResponse,
    ChildResponse,
    ChildUpdateRequest,
)
from .service import MobileChildrenService

router = APIRouter()


@router.get(
    '/me/children',
    response_model=ChildListResponse,
    responses={401: {'model': ErrorResponse}},
)
def list_children(
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileChildrenService = Depends(get_mobile_children_service),
) -> ChildListResponse:
    return service.list_children(user)


@router.post(
    '/me/children',
    response_model=ChildResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        401: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def create_child(
    payload: ChildCreateRequest,
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileChildrenService = Depends(get_mobile_children_service),
) -> ChildResponse:
    return service.create_child(user, payload)


@router.patch(
    '/me/children/{child_id}',
    response_model=ChildResponse,
    responses={
        401: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_child(
    child_id: str,
    payload: ChildUpdateRequest,
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileChildrenService = Depends(get_mobile_children_service),
) -> ChildResponse:
    return service.update_child(user, child_id, payload)


@router.delete(
    '/me/children/{child_id}',
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        401: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def delete_child(
    child_id: str,
    user: MobileUser = Depends(get_authenticated_mobile_user),
    service: MobileChildrenService = Depends(get_mobile_children_service),
) -> None:
    service.delete_child(user, child_id)
