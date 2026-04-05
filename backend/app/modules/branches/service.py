from ...db.repositories.branch_repository import BranchRepository
from .schemas import BranchSummary


class BranchService:
    def __init__(self, repository: BranchRepository | None = None) -> None:
        self.repository = repository or BranchRepository()

    def list_branches(self) -> list[BranchSummary]:
        return [
            BranchSummary.model_validate(branch)
            for branch in self.repository.list_active()
        ]

