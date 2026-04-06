from uuid import uuid4

from ..models.birthday_request import BirthdayRequest
from .base import Repository


class LeadRepository(Repository):
    def create(self, payload: dict[str, str]) -> dict[str, str]:
        return {
            'id': f'lead_{uuid4().hex}',
            'type': payload['type'],
            'status': 'new',
        }

    def create_birthday_lead(self, payload: dict[str, object]) -> BirthdayRequest:
        request = BirthdayRequest(
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
