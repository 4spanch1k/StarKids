from sqlalchemy import or_, select

from ..models.branch import Branch
from .base import Repository


class BranchRepository(Repository):
    def list_all(self, include_inactive: bool = True) -> list[Branch]:
        statement = select(Branch)
        if not include_inactive:
            statement = statement.where(Branch.is_active.is_(True))
        statement = statement.order_by(Branch.display_order.asc(), Branch.name.asc())
        return list(self.db.scalars(statement).all())

    def list_active(self) -> list[Branch]:
        return self.list_all(include_inactive=False)

    def get_by_id(self, branch_id: str) -> Branch | None:
        statement = select(Branch).where(Branch.id == branch_id)
        return self.db.scalar(statement)

    def get_active_by_id(self, branch_id: str) -> Branch | None:
        branch = self.get_by_id(branch_id)
        if branch is None or not branch.is_active:
            return None
        return branch

    def get_by_slug(self, slug: str) -> Branch | None:
        statement = select(Branch).where(Branch.slug == slug)
        return self.db.scalar(statement)

    def get_by_id_or_slug(self, branch_id_or_slug: str) -> Branch | None:
        statement = select(Branch).where(
            or_(Branch.id == branch_id_or_slug, Branch.slug == branch_id_or_slug),
        )
        return self.db.scalar(statement)

    def get_active_by_id_or_slug(self, branch_id_or_slug: str) -> Branch | None:
        branch = self.get_by_id_or_slug(branch_id_or_slug)
        if branch is None or not branch.is_active:
            return None
        return branch

    def slug_exists(self, slug: str, exclude_id: str | None = None) -> bool:
        statement = select(Branch.id).where(Branch.slug == slug)
        if exclude_id:
            statement = statement.where(Branch.id != exclude_id)
        return self.db.scalar(statement) is not None

    def create(self, payload: dict[str, object]) -> Branch:
        branch = Branch(**payload)
        self.db.add(branch)
        self.db.commit()
        self.db.refresh(branch)
        return branch

    def save(self, branch: Branch) -> Branch:
        self.db.add(branch)
        self.db.commit()
        self.db.refresh(branch)
        return branch
