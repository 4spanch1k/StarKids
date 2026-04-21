from fastapi import APIRouter, Depends, Query, Request, Response, status
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.repositories.news_event_repository import NewsEventRepository
from ...db.repositories.news_repository import NewsRepository
from ..mobile_auth.dependencies import get_optional_authenticated_mobile_user
from .schemas import MobileNewsEventRequest
from .schemas import MobileNewsItem
from .service import NewsService

router = APIRouter()


def get_news_service(
    session: Session = Depends(get_db_session),
) -> NewsService:
    return NewsService(
        repository=NewsRepository(session),
        event_repository=NewsEventRepository(session),
    )


@router.get('/news', response_model=list[MobileNewsItem])
def list_news(
    limit: int = Query(default=10, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
    service: NewsService = Depends(get_news_service),
) -> list[MobileNewsItem]:
    return service.list_news(limit=limit, offset=offset)


@router.get('/news/{news_id}', response_model=MobileNewsItem)
def get_news(
    news_id: str,
    service: NewsService = Depends(get_news_service),
) -> MobileNewsItem:
    return service.get_news(news_id)


@router.post(
    '/news/{news_id}/events',
    status_code=status.HTTP_204_NO_CONTENT,
)
def record_news_event(
    news_id: str,
    payload: MobileNewsEventRequest,
    request: Request,
    current_user=Depends(get_optional_authenticated_mobile_user),
    service: NewsService = Depends(get_news_service),
) -> Response:
    service.record_event(
        news_id,
        event_type=payload.event_type,
        actor_id=current_user.id if current_user is not None else '',
        client_ip=request.client.host if request.client is not None else '',
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
