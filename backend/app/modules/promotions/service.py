from ...core.exceptions.http import NotFoundException
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.promotion_repository import PromotionRepository
from .schemas import PromotionSummary


class PromotionsService:
    def __init__(
        self,
        *,
        repository: PromotionRepository | None = None,
        branch_repository: BranchRepository | None = None,
    ) -> None:
        self.repository = repository or PromotionRepository()
        self.branch_repository = branch_repository or BranchRepository()

    def list_promotions(self, branch_id: str | None = None) -> list[PromotionSummary]:
        resolved_branch_id: str | None = None
        if branch_id:
            branch = self.branch_repository.get_active_by_id_or_slug(branch_id)
            if branch is None:
                raise NotFoundException(
                    code='branch_not_found',
                    message='Branch was not found.',
                )
            resolved_branch_id = branch.id

        promotions = self.repository.list_mobile(branch_id=resolved_branch_id)
        branch_ids_map = self.repository.get_branch_ids_map([promotion.id for promotion in promotions])
        return [
            PromotionSummary(
                id=promotion.id,
                title=promotion.title,
                description=promotion.description,
                badge_label=promotion.badge_label,
                image_url=promotion.image_url,
                branch_ids=branch_ids_map.get(promotion.id, []),
                cta_label=promotion.cta_label,
            )
            for promotion in promotions
        ]
