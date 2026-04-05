from ...db.repositories.lead_repository import LeadRepository
from .schemas import BirthdayLeadCreate, ContactLeadCreate, LeadCreatedResponse


class LeadService:
    def __init__(self, repository: LeadRepository | None = None) -> None:
        self.repository = repository or LeadRepository()

    def create_contact_lead(self, payload: ContactLeadCreate) -> LeadCreatedResponse:
        lead = self.repository.create({'type': 'contact', 'phone': payload.phone})
        return LeadCreatedResponse.model_validate(lead)

    def create_birthday_lead(
        self,
        payload: BirthdayLeadCreate,
    ) -> LeadCreatedResponse:
        lead = self.repository.create({'type': 'birthday', 'phone': payload.phone})
        return LeadCreatedResponse.model_validate(lead)

