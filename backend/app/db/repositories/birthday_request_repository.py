from ..models.birthday_request import BirthdayRequest
from .base import Repository


class BirthdayRequestRepository(Repository):
    def create(self, payload: dict[str, object]) -> BirthdayRequest:
        birthday_request = BirthdayRequest(**payload)
        self.db.add(birthday_request)
        self.db.commit()
        self.db.refresh(birthday_request)
        return birthday_request
