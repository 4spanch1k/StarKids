from sqlalchemy import select

from ..models.visit import Visit
from .base import Repository


class VisitRepository(Repository):
    def get_for_payment(self, mobile_payment_id: str, *, for_update: bool = False) -> Visit | None:
        statement = select(Visit).where(Visit.mobile_payment_id == mobile_payment_id)
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def get_active_for_user(self, mobile_user_id: str) -> Visit | None:
        statement = (
            select(Visit)
            .where(Visit.mobile_user_id == mobile_user_id, Visit.status == 'active')
            .order_by(Visit.started_at.desc())
            .limit(1)
        )
        return self.db.scalar(statement)

    def add(self, visit: Visit) -> Visit:
        self.db.add(visit)
        return visit
