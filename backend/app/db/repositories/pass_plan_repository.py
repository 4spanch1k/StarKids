from sqlalchemy import select

from ..models.pass_plan import PassPlan
from .base import Repository


class PassPlanRepository(Repository):
    def list_active(self, *, branch_id: str | None = None) -> list[PassPlan]:
        statement = select(PassPlan).where(PassPlan.is_active.is_(True)).order_by(PassPlan.created_at.asc())
        if branch_id is not None:
            statement = statement.where((PassPlan.branch_id.is_(None)) | (PassPlan.branch_id == branch_id))
        return list(self.db.scalars(statement).all())

    def list_all(self) -> list[PassPlan]:
        return list(self.db.scalars(select(PassPlan).order_by(PassPlan.created_at.desc())).all())

    def get(self, plan_id: str, *, for_update: bool = False) -> PassPlan | None:
        statement = select(PassPlan).where(PassPlan.id == plan_id)
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def add(self, plan: PassPlan) -> PassPlan:
        self.db.add(plan)
        return plan
