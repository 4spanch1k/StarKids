from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.repositories.news_repository import NewsRepository
from .schemas import MobileNewsItem
from .service import NewsService

router = APIRouter()


def get_news_service(
    session: Session = Depends(get_db_session),
) -> NewsService:
    return NewsService(repository=NewsRepository(session))


@router.get('/news', response_model=list[MobileNewsItem])
def list_news(
    service: NewsService = Depends(get_news_service),
) -> list[MobileNewsItem]:
    return service.list_news()
