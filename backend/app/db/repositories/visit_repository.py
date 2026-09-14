from datetime import datetime

from sqlalchemy import func, select

from ..models.branch import Branch
from ..models.visit import Visit
from .base import Repository

COMPLETED_VISIT_STATUS = 'completed'


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

    def get_completed_stats_for_user(
        self,
        mobile_user_id: str,
    ) -> tuple[int, datetime | None, datetime | None]:
        """Return visit history stats, excluding an in-progress admission."""
        row = self.db.execute(
            select(
                func.count(Visit.id),
                func.min(Visit.started_at),
                func.max(Visit.started_at),
            ).where(
                Visit.mobile_user_id == mobile_user_id,
                Visit.status == COMPLETED_VISIT_STATUS,
            )
        ).one()
        count, first_visit_at, last_visit_at = row
        return int(count or 0), first_visit_at, last_visit_at

    def list_completed_for_user(
        self,
        mobile_user_id: str,
        *,
        limit: int = 50,
    ) -> list[tuple[Visit, Branch | None]]:
        statement = (
            select(Visit, Branch)
            .outerjoin(Branch, Branch.id == Visit.branch_id)
            .where(
                Visit.mobile_user_id == mobile_user_id,
                Visit.status == COMPLETED_VISIT_STATUS,
            )
            .order_by(Visit.started_at.desc(), Visit.id.desc())
            .limit(limit)
        )
        return list(self.db.execute(statement).all())

    def add(self, visit: Visit) -> Visit:
        self.db.add(visit)
        return visit
