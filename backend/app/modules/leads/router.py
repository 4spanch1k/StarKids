from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.birthday_package_repository import BirthdayPackageRepository
from ...db.repositories.lead_repository import LeadRepository
from .schemas import (
    BirthdayLeadCreate,
    BirthdayLeadGenericErrorResponse,
    BirthdayLeadSubmittedResponse,
    BirthdayLeadValidationErrorResponse,
    ContactLeadCreate,
    LeadCreatedResponse,
)
from .service import LeadService

router = APIRouter()
service = LeadService()


@router.post(
    '/leads/contact',
    response_model=LeadCreatedResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_contact_lead(payload: ContactLeadCreate) -> LeadCreatedResponse:
    return service.create_contact_lead(payload)


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
) -> BirthdayLeadSubmittedResponse:
    birthday_lead_service = LeadService(
        repository=LeadRepository(session),
        branch_repository=BranchRepository(session),
        package_repository=BirthdayPackageRepository(session),
    )
    return birthday_lead_service.create_birthday_lead(payload)
