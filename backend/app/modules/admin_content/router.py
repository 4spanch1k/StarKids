from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.content_block_repository import ContentBlockRepository
from ...db.repositories.faq_repository import FAQRepository
from ..admin_auth.dependencies import require_admin_roles
from .schemas import (
    AdminContentBlockCreateRequest,
    AdminContentBlockListQuery,
    AdminContentBlockResponse,
    AdminContentBlockUpdateRequest,
    AdminFAQCreateRequest,
    AdminFAQListQuery,
    AdminFAQResponse,
    AdminFAQUpdateRequest,
)
from .service import AdminContentService, CONTENT_ADMIN_ALLOWED_ROLES

router = APIRouter(
    dependencies=[Depends(require_admin_roles(*CONTENT_ADMIN_ALLOWED_ROLES))]
)


def get_admin_content_service(
    session: Session = Depends(get_db_session),
) -> AdminContentService:
    return AdminContentService(
        faq_repository=FAQRepository(session),
        content_block_repository=ContentBlockRepository(session),
    )


@router.get(
    '/faqs',
    response_model=list[AdminFAQResponse],
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def list_admin_faqs(
    query: Annotated[AdminFAQListQuery, Depends()],
    service: AdminContentService = Depends(get_admin_content_service),
) -> list[AdminFAQResponse]:
    return service.list_faqs(query)


@router.get(
    '/faqs/{faq_id}',
    response_model=AdminFAQResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_faq(
    faq_id: str,
    service: AdminContentService = Depends(get_admin_content_service),
) -> AdminFAQResponse:
    return service.get_faq(faq_id)


@router.post(
    '/faqs',
    response_model=AdminFAQResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def create_admin_faq(
    payload: AdminFAQCreateRequest,
    service: AdminContentService = Depends(get_admin_content_service),
) -> AdminFAQResponse:
    return service.create_faq(payload)


@router.patch(
    '/faqs/{faq_id}',
    response_model=AdminFAQResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_faq(
    faq_id: str,
    payload: AdminFAQUpdateRequest,
    service: AdminContentService = Depends(get_admin_content_service),
) -> AdminFAQResponse:
    return service.update_faq(faq_id, payload)


@router.get(
    '/content-blocks',
    response_model=list[AdminContentBlockResponse],
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def list_admin_content_blocks(
    query: Annotated[AdminContentBlockListQuery, Depends()],
    service: AdminContentService = Depends(get_admin_content_service),
) -> list[AdminContentBlockResponse]:
    return service.list_content_blocks(query)


@router.get(
    '/content-blocks/{block_id}',
    response_model=AdminContentBlockResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_content_block(
    block_id: str,
    service: AdminContentService = Depends(get_admin_content_service),
) -> AdminContentBlockResponse:
    return service.get_content_block(block_id)


@router.post(
    '/content-blocks',
    response_model=AdminContentBlockResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def create_admin_content_block(
    payload: AdminContentBlockCreateRequest,
    service: AdminContentService = Depends(get_admin_content_service),
) -> AdminContentBlockResponse:
    return service.create_content_block(payload)


@router.patch(
    '/content-blocks/{block_id}',
    response_model=AdminContentBlockResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_content_block(
    block_id: str,
    payload: AdminContentBlockUpdateRequest,
    service: AdminContentService = Depends(get_admin_content_service),
) -> AdminContentBlockResponse:
    return service.update_content_block(block_id, payload)
