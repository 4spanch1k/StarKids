from sqlalchemy import or_, select

from ..models.branch import Branch
from .base import Repository


class BranchRepository(Repository):
    def list_active(self) -> list[Branch]:
        statement = (
            select(Branch)
            .where(Branch.is_active.is_(True))
            .order_by(Branch.display_order.asc(), Branch.name.asc())
        )
        return list(self.db.scalars(statement).all())

    def get_active_by_id(self, branch_id: str) -> Branch | None:
        statement = select(Branch).where(
            Branch.id == branch_id,
            Branch.is_active.is_(True),
        )
        return self.db.scalar(statement)

    def get_active_by_id_or_slug(self, branch_id_or_slug: str) -> Branch | None:
        statement = select(Branch).where(
            or_(Branch.id == branch_id_or_slug, Branch.slug == branch_id_or_slug),
            Branch.is_active.is_(True),
        )
        return self.db.scalar(statement)
