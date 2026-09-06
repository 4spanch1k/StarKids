from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.models.mobile_user import MobileUser
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.lead_repository import LeadRepository
from ...db.repositories.mobile_child_repository import MobileChildRepository
from ..mobile_auth.dependencies import get_optional_authenticated_mobile_user
from ..mobile_children.dependencies import get_authenticated_mobile_user
from .schemas import (
    BirthdayLeadCreate,
    BirthdayLeadGenericErrorResponse,
    BirthdayLeadListResponse,
    BirthdayLeadResponse,
    BirthdayLeadSubmittedResponse,
    BirthdayLeadValidationErrorResponse,
    ContactLeadCreate,
    LeadCreatedResponse,
)
from .service import LeadService

router = APIRouter()


@router.post(
    '/leads/contact',
    response_model=LeadCreatedResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_contact_lead(
    payload: ContactLeadCreate,
    session: Session = Depends(get_db_session),
    mobile_user: MobileUser | None = Depends(get_optional_authenticated_mobile_user),
) -> LeadCreatedResponse:
    contact_lead_service = LeadService(
        repository=LeadRepository(session),
    )
    return contact_lead_service.create_contact_lead(
        payload,
        mobile_user_id=mobile_user.id if mobile_user is not None else None,
    )


@router.post(
    '/leads/birthday',
    response_model=BirthdayLeadSubmittedResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        404: {'model': BirthdayLeadValidationErrorResponse},
        422: {'model': BirthdayLeadValidationErrorResponse},
        500: {'model': BirthdayLeadGenericErrorResponse},
    },
)
def create_birthday_lead(
    payload: BirthdayLeadCreate,
    session: Session = Depends(get_db_session),
    mobile_user: MobileUser | None = Depends(get_optional_authenticated_mobile_user),
) -> BirthdayLeadSubmittedResponse:
    birthday_lead_service = LeadService(
        repository=LeadRepository(session),
        branch_repository=BranchRepository(session),
        package_repository=BirthdayPackageRepository(session),
        child_repository=MobileChildRepository(session),
    )
    return birthday_lead_service.create_birthday_lead(
        payload,
        mobile_user_id=mobile_user.id if mobile_user is not None else None,
    )


def _authenticated_lead_service(session: Session) -> LeadService:
    return LeadService(
        repository=LeadRepository(session),
        branch_repository=BranchRepository(session),
        package_repository=BirthdayPackageRepository(session),
        child_repository=MobileChildRepository(session),
    )


@router.get('/leads/birthday', response_model=BirthdayLeadListResponse)
def list_birthday_leads(
    session: Session = Depends(get_db_session),
    mobile_user: MobileUser = Depends(get_authenticated_mobile_user),
) -> BirthdayLeadListResponse:
    return _authenticated_lead_service(session).list_birthday_leads(mobile_user.id)


@router.get('/leads/birthday/{lead_id}', response_model=BirthdayLeadResponse)
def get_birthday_lead(
    lead_id: str,
    session: Session = Depends(get_db_session),
    mobile_user: MobileUser = Depends(get_authenticated_mobile_user),
) -> BirthdayLeadResponse:
    return _authenticated_lead_service(session).get_birthday_lead(lead_id, mobile_user.id)
