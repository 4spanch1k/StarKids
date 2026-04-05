from fastapi import APIRouter, status

from .schemas import BirthdayLeadCreate, ContactLeadCreate, LeadCreatedResponse
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
    response_model=LeadCreatedResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_birthday_lead(payload: BirthdayLeadCreate) -> LeadCreatedResponse:
    return service.create_birthday_lead(payload)

