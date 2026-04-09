from ..models.birthday_request import BirthdayRequest
from ..models.contact_lead import ContactLead
from .base import Repository


class LeadRepository(Repository):
    def create_contact_lead(self, payload: dict[str, object]) -> ContactLead:
        lead = ContactLead(
            mobile_user_id=payload.get('mobile_user_id'),
            customer_name=payload['customer_name'],
            phone=payload['phone'],
            email=payload.get('email'),
            message=payload.get('message'),
        )
        self.db.add(lead)
        self.db.commit()
        self.db.refresh(lead)
        return lead

    def create_birthday_lead(self, payload: dict[str, object]) -> BirthdayRequest:
        request = BirthdayRequest(
            mobile_user_id=payload.get('mobile_user_id'),
            branch_id=payload['branch_id'],
            birthday_package_id=payload.get('birthday_package_id'),
            customer_name=payload['customer_name'],
            phone=payload['phone'],
            requested_date=payload.get('requested_date'),
            guest_count=payload.get('guest_count'),
            notes=payload.get('notes'),
        )
        self.db.add(request)
        self.db.commit()
        self.db.refresh(request)
        return request
