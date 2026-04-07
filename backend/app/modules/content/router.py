from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.content_block_repository import ContentBlockRepository
from ...db.repositories.faq_repository import FAQRepository
from .schemas import ContentBlockListQuery, ContentBlockResponse, FAQResponse
from .service import ContentService

router = APIRouter()


def get_content_service(
    session: Session = Depends(get_db_session),
) -> ContentService:
    return ContentService(
        faq_repository=FAQRepository(session),
        content_block_repository=ContentBlockRepository(session),
    )


@router.get(
    '/faqs',
    response_model=list[FAQResponse],
    responses={422: {'model': ErrorResponse}},
)
def list_faqs(
    service: ContentService = Depends(get_content_service),
) -> list[FAQResponse]:
    return service.list_faqs()


@router.get(
    '/content-blocks',
    response_model=list[ContentBlockResponse],
    responses={422: {'model': ErrorResponse}},
)
def list_content_blocks(
    query: Annotated[ContentBlockListQuery, Depends()],
    service: ContentService = Depends(get_content_service),
) -> list[ContentBlockResponse]:
    return service.list_content_blocks(query.surface)
