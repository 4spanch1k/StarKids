from fastapi import APIRouter, Depends, Query, Request, Response, UploadFile, status
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...core.storage.backend import get_storage_backend
from ...db.repositories.mobile_notification_repository import (
    MobileNotificationRepository,
)
from ...db.repositories.news_event_repository import NewsEventRepository
from ...db.repositories.news_repository import NewsRepository
from ..admin_auth.dependencies import require_admin_roles
from .schemas import (
    AdminNewsCreateRequest,
    AdminNewsImageUploadResponse,
    AdminNewsResponse,
    AdminNewsStatsResponse,
    AdminNewsTopStatsResponse,
    AdminNewsUpdateRequest,
)
from .service import AdminNewsService, NEWS_ADMIN_ALLOWED_ROLES

router = APIRouter(
    dependencies=[Depends(require_admin_roles(*NEWS_ADMIN_ALLOWED_ROLES))]
)


def get_admin_news_service(
    session: Session = Depends(get_db_session),
) -> AdminNewsService:
    from ...core.config.settings import get_settings

    settings = get_settings()
    storage = get_storage_backend(settings)
    return AdminNewsService(
        repository=NewsRepository(session),
        notification_repository=MobileNotificationRepository(session),
        event_repository=NewsEventRepository(session),
        storage=storage,
        settings=settings,
    )


@router.get(
    '/news',
    response_model=list[AdminNewsResponse],
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}},
)
def list_admin_news(
    service: AdminNewsService = Depends(get_admin_news_service),
) -> list[AdminNewsResponse]:
    return service.list_news()


@router.get(
    '/news/stats/top',
    response_model=AdminNewsTopStatsResponse,
    responses={401: {'model': ErrorResponse}, 403: {'model': ErrorResponse}},
)
def get_admin_news_top_stats(
    limit: int = Query(default=5, ge=1, le=20),
    service: AdminNewsService = Depends(get_admin_news_service),
) -> AdminNewsTopStatsResponse:
    return service.get_top_stats(limit=limit)


@router.get(
    '/news/{news_id}',
    response_model=AdminNewsResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_news(
    news_id: str,
    service: AdminNewsService = Depends(get_admin_news_service),
) -> AdminNewsResponse:
    return service.get_news(news_id)


@router.get(
    '/news/{news_id}/stats',
    response_model=AdminNewsStatsResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_news_stats(
    news_id: str,
    service: AdminNewsService = Depends(get_admin_news_service),
) -> AdminNewsStatsResponse:
    return service.get_news_stats(news_id)


@router.post(
    '/news',
    response_model=AdminNewsResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def create_admin_news(
    payload: AdminNewsCreateRequest,
    service: AdminNewsService = Depends(get_admin_news_service),
) -> AdminNewsResponse:
    return service.create_news(payload)


@router.patch(
    '/news/{news_id}',
    response_model=AdminNewsResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_news(
    news_id: str,
    payload: AdminNewsUpdateRequest,
    service: AdminNewsService = Depends(get_admin_news_service),
) -> AdminNewsResponse:
    return service.update_news(news_id, payload)


@router.delete(
    '/news/{news_id}',
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def delete_admin_news(
    news_id: str,
    service: AdminNewsService = Depends(get_admin_news_service),
) -> Response:
    service.delete_news(news_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    '/news/upload-image',
    response_model=AdminNewsImageUploadResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
async def upload_admin_news_image(
    request: Request,
    file: UploadFile,
    service: AdminNewsService = Depends(get_admin_news_service),
) -> AdminNewsImageUploadResponse:
    public_base_url = str(request.base_url).rstrip('/')
    return await service.upload_image(file, public_base_url=public_base_url)
