from ...db.repositories.branch_repository import BranchRepository
from ...core.exceptions.http import NotFoundException
from .schemas import BranchDetail, BranchSummary


class BranchService:
    def __init__(self, repository: BranchRepository | None = None) -> None:
        self.repository = repository or BranchRepository()

    def list_branches(self) -> list[BranchSummary]:
        return [
            BranchSummary.model_validate(branch)
            for branch in self.repository.list_active()
        ]

    def get_branch(self, branch_id_or_slug: str) -> BranchDetail:
        branch = self.repository.get_active_by_id_or_slug(branch_id_or_slug)
        if branch is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Branch was not found.',
            )
        return BranchDetail.model_validate(branch)
