from fastapi import APIRouter, Depends, Path
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.schemas import ErrorResponse
from ...db.repositories.branch_menu_repository import BranchMenuRepository
from ...db.repositories.branch_pricing_repository import BranchPricingRepository
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.branch_ticket_repository import BranchTicketRepository
from .schemas import (
    BranchContactsResponse,
    BranchDetail,
    BranchGalleryResponse,
    BranchMenuResponse,
    BranchPricesRulesResponse,
    BranchSummary,
    BranchTicketsResponse,
)
from .service import BranchService

router = APIRouter()


@router.get(
    '/branches',
    response_model=list[BranchSummary],
    responses={422: {'model': ErrorResponse}},
)
def list_branches(
    session: Session = Depends(get_db_session),
) -> list[BranchSummary]:
    service = BranchService(repository=BranchRepository(session))
    return service.list_branches()


@router.get(
    '/branches/{branch_id_or_slug}',
    response_model=BranchDetail,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_branch(
    branch_id_or_slug: str = Path(min_length=2, max_length=120),
    session: Session = Depends(get_db_session),
) -> BranchDetail:
    service = BranchService(repository=BranchRepository(session))
    return service.get_branch(branch_id_or_slug)


@router.get(
    '/branches/{branch_id_or_slug}/contacts',
    response_model=BranchContactsResponse,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_branch_contacts(
    branch_id_or_slug: str = Path(min_length=2, max_length=120),
    session: Session = Depends(get_db_session),
) -> BranchContactsResponse:
    service = BranchService(
        repository=BranchRepository(session),
        pricing_repository=BranchPricingRepository(session),
        menu_repository=BranchMenuRepository(session),
        ticket_repository=BranchTicketRepository(session),
    )
    return service.get_branch_contacts(branch_id_or_slug)


@router.get(
    '/branches/{branch_id_or_slug}/gallery',
    response_model=BranchGalleryResponse,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_branch_gallery(
    branch_id_or_slug: str = Path(min_length=2, max_length=120),
    session: Session = Depends(get_db_session),
) -> BranchGalleryResponse:
    service = BranchService(repository=BranchRepository(session))
    return service.get_branch_gallery(branch_id_or_slug)


@router.get(
    '/branches/{branch_id_or_slug}/prices-rules',
    response_model=BranchPricesRulesResponse,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_branch_prices_rules(
    branch_id_or_slug: str = Path(min_length=2, max_length=120),
    session: Session = Depends(get_db_session),
) -> BranchPricesRulesResponse:
    service = BranchService(
        repository=BranchRepository(session),
        pricing_repository=BranchPricingRepository(session),
        menu_repository=BranchMenuRepository(session),
        ticket_repository=BranchTicketRepository(session),
    )
    return service.get_branch_prices_rules(branch_id_or_slug)


@router.get(
    '/branches/{branch_id_or_slug}/menu',
    response_model=BranchMenuResponse,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_branch_menu(
    branch_id_or_slug: str = Path(min_length=2, max_length=120),
    session: Session = Depends(get_db_session),
) -> BranchMenuResponse:
    service = BranchService(
        repository=BranchRepository(session),
        pricing_repository=BranchPricingRepository(session),
        menu_repository=BranchMenuRepository(session),
        ticket_repository=BranchTicketRepository(session),
    )
    return service.get_branch_menu(branch_id_or_slug)


@router.get(
    '/branches/{branch_id_or_slug}/tickets',
    response_model=BranchTicketsResponse,
    responses={
        404: {'model': ErrorResponse},
        422: {'model': ErrorResponse},
    },
)
def get_branch_tickets(
    branch_id_or_slug: str = Path(min_length=2, max_length=120),
    session: Session = Depends(get_db_session),
) -> BranchTicketsResponse:
    service = BranchService(
        repository=BranchRepository(session),
        pricing_repository=BranchPricingRepository(session),
        menu_repository=BranchMenuRepository(session),
        ticket_repository=BranchTicketRepository(session),
    )
    return service.get_branch_tickets(branch_id_or_slug)
