from sqlalchemy import select

from ..models.birthday_request import BirthdayRequest
from ..models.contact_lead import ContactLead
from .base import Repository


class LeadRepository(Repository):
    def list_birthday_leads_for_user(self, mobile_user_id: str) -> list[BirthdayRequest]:
        return list(
            self.db.scalars(
                select(BirthdayRequest)
                .where(BirthdayRequest.mobile_user_id == mobile_user_id)
                .order_by(BirthdayRequest.created_at.desc())
            )
        )

    def get_birthday_lead_for_user(self, lead_id: str, mobile_user_id: str) -> BirthdayRequest | None:
        return self.db.scalar(
            select(BirthdayRequest).where(
                BirthdayRequest.id == lead_id,
                BirthdayRequest.mobile_user_id == mobile_user_id,
            )
        )

    def get_birthday_lead_by_idempotency_key(
        self, *, mobile_user_id: str, idempotency_key: str
    ) -> BirthdayRequest | None:
        return self.db.scalar(
            select(BirthdayRequest).where(
                BirthdayRequest.mobile_user_id == mobile_user_id,
                BirthdayRequest.idempotency_key == idempotency_key,
            )
        )

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
            child_id=payload.get('child_id'),
            idempotency_key=payload.get('idempotency_key'),
            child_name_snapshot=payload.get('child_name_snapshot'),
            child_birth_date_snapshot=payload.get('child_birth_date_snapshot'),
            package_name_snapshot=payload.get('package_name_snapshot'),
            package_price_snapshot=payload.get('package_price_snapshot'),
        )
        self.db.add(request)
        self.db.commit()
        self.db.refresh(request)
        return request
