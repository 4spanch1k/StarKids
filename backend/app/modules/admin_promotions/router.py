from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.promotion_repository import PromotionRepository
from ..admin_auth.dependencies import require_admin_roles
from .schemas import (
    AdminPromotionCreateRequest,
    AdminPromotionListQuery,
    AdminPromotionResponse,
    AdminPromotionUpdateRequest,
)
from .service import AdminPromotionService, PROMOTION_ADMIN_ALLOWED_ROLES

router = APIRouter(
    dependencies=[Depends(require_admin_roles(*PROMOTION_ADMIN_ALLOWED_ROLES))]
)


def get_admin_promotion_service(
    session: Session = Depends(get_db_session),
) -> AdminPromotionService:
    return AdminPromotionService(
        repository=PromotionRepository(session),
        branch_repository=BranchRepository(session),
    )


@router.get(
    '/promotions',
    response_model=list[AdminPromotionResponse],
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def list_admin_promotions(
    query: Annotated[AdminPromotionListQuery, Depends()],
    service: AdminPromotionService = Depends(get_admin_promotion_service),
) -> list[AdminPromotionResponse]:
    return service.list_promotions(query)


@router.get(
    '/promotions/{promotion_id}',
    response_model=AdminPromotionResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_promotion(
    promotion_id: str,
    service: AdminPromotionService = Depends(get_admin_promotion_service),
) -> AdminPromotionResponse:
    return service.get_promotion(promotion_id)


@router.post(
    '/promotions',
    response_model=AdminPromotionResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def create_admin_promotion(
    payload: AdminPromotionCreateRequest,
    service: AdminPromotionService = Depends(get_admin_promotion_service),
) -> AdminPromotionResponse:
    return service.create_promotion(payload)


@router.patch(
    '/promotions/{promotion_id}',
    response_model=AdminPromotionResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_promotion(
    promotion_id: str,
    payload: AdminPromotionUpdateRequest,
    service: AdminPromotionService = Depends(get_admin_promotion_service),
) -> AdminPromotionResponse:
    return service.update_promotion(promotion_id, payload)
