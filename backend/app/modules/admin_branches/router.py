from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.branch_pricing_repository import BranchPricingRepository
from ...db.repositories.branch_repository import BranchRepository
from ..admin_auth.dependencies import require_admin_roles
from .schemas import (
    AdminBranchContactsResponse,
    AdminBranchContactsUpdateRequest,
    AdminBranchCreateRequest,
    AdminBranchDetailResponse,
    AdminBranchGalleryResponse,
    AdminBranchGalleryUpdateRequest,
    AdminBranchListQuery,
    AdminBranchPricesRulesResponse,
    AdminBranchPricesRulesUpsertRequest,
    AdminBranchSummaryResponse,
    AdminBranchUpdateRequest,
)
from .service import AdminBranchService, BRANCH_ADMIN_ALLOWED_ROLES

router = APIRouter(
    dependencies=[Depends(require_admin_roles(*BRANCH_ADMIN_ALLOWED_ROLES))]
)


def get_admin_branch_service(
    session: Session = Depends(get_db_session),
) -> AdminBranchService:
    return AdminBranchService(
        repository=BranchRepository(session),
        pricing_repository=BranchPricingRepository(session),
    )


@router.get(
    '/branches',
    response_model=list[AdminBranchSummaryResponse],
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def list_admin_branches(
    query: Annotated[AdminBranchListQuery, Depends()],
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> list[AdminBranchSummaryResponse]:
    return service.list_branches(query)


@router.get(
    '/branches/{branch_id}',
    response_model=AdminBranchDetailResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_branch(
    branch_id: str,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchDetailResponse:
    return service.get_branch(branch_id)


@router.post(
    '/branches',
    response_model=AdminBranchDetailResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def create_admin_branch(
    payload: AdminBranchCreateRequest,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchDetailResponse:
    return service.create_branch(payload)


@router.patch(
    '/branches/{branch_id}',
    response_model=AdminBranchDetailResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_branch(
    branch_id: str,
    payload: AdminBranchUpdateRequest,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchDetailResponse:
    return service.update_branch(branch_id, payload)


@router.get(
    '/branches/{branch_id}/contacts',
    response_model=AdminBranchContactsResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_branch_contacts(
    branch_id: str,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchContactsResponse:
    return service.get_branch_contacts(branch_id)


@router.put(
    '/branches/{branch_id}/contacts',
    response_model=AdminBranchContactsResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_branch_contacts(
    branch_id: str,
    payload: AdminBranchContactsUpdateRequest,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchContactsResponse:
    return service.update_branch_contacts(branch_id, payload)


@router.get(
    '/branches/{branch_id}/gallery',
    response_model=AdminBranchGalleryResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_branch_gallery(
    branch_id: str,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchGalleryResponse:
    return service.get_branch_gallery(branch_id)


@router.put(
    '/branches/{branch_id}/gallery',
    response_model=AdminBranchGalleryResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def update_admin_branch_gallery(
    branch_id: str,
    payload: AdminBranchGalleryUpdateRequest,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchGalleryResponse:
    return service.update_branch_gallery(branch_id, payload)


@router.get(
    '/branches/{branch_id}/prices-rules',
    response_model=AdminBranchPricesRulesResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
    },
)
def get_admin_branch_prices_rules(
    branch_id: str,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchPricesRulesResponse:
    return service.get_branch_prices_rules(branch_id)


@router.put(
    '/branches/{branch_id}/prices-rules',
    response_model=AdminBranchPricesRulesResponse,
    responses={
        401: {'model': ErrorResponse},
        403: {'model': ErrorResponse},
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def upsert_admin_branch_prices_rules(
    branch_id: str,
    payload: AdminBranchPricesRulesUpsertRequest,
    service: AdminBranchService = Depends(get_admin_branch_service),
) -> AdminBranchPricesRulesResponse:
    return service.upsert_branch_prices_rules(branch_id, payload)
