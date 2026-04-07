from ...core.exceptions.http import NotFoundException
from ...db.models.promotion import Promotion
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.promotion_repository import PromotionRepository
from .schemas import (
    AdminPromotionCreateRequest,
    AdminPromotionListQuery,
    AdminPromotionResponse,
    AdminPromotionUpdateRequest,
)

PROMOTION_ADMIN_ALLOWED_ROLES = ('super_admin', 'content_manager')


class AdminPromotionService:
    def __init__(
        self,
        *,
        repository: PromotionRepository | None = None,
        branch_repository: BranchRepository | None = None,
    ) -> None:
        self.repository = repository or PromotionRepository()
        self.branch_repository = branch_repository or BranchRepository()

    def list_promotions(
        self,
        query: AdminPromotionListQuery,
    ) -> list[AdminPromotionResponse]:
        if query.branch_id:
            self._ensure_branch_exists(query.branch_id)
        promotions = self.repository.list_admin(
            branch_id=query.branch_id,
            is_active=query.is_active,
            is_published=query.is_published,
        )
        return self._serialize_many(promotions)

    def get_promotion(self, promotion_id: str) -> AdminPromotionResponse:
        promotion = self._get_promotion_or_404(promotion_id)
        return self._serialize_one(promotion)

    def create_promotion(
        self,
        payload: AdminPromotionCreateRequest,
    ) -> AdminPromotionResponse:
        branch_ids = self._validated_branch_ids(payload.branch_ids)
        promotion = self.repository.create(
            payload=payload.model_dump(exclude={'branch_ids'}),
            branch_ids=branch_ids,
        )
        return self._serialize_one(promotion)

    def update_promotion(
        self,
        promotion_id: str,
        payload: AdminPromotionUpdateRequest,
    ) -> AdminPromotionResponse:
        promotion = self._get_promotion_or_404(promotion_id)
        changes = payload.model_dump(exclude_unset=True)
        if not changes:
            return self._serialize_one(promotion)

        branch_ids = None
        if 'branch_ids' in changes:
            branch_ids = self._validated_branch_ids(changes.pop('branch_ids') or [])

        for key, value in changes.items():
            setattr(promotion, key, value)

        saved = self.repository.save(
            promotion=promotion,
            branch_ids=branch_ids if branch_ids is not None else self.repository.get_branch_ids(promotion.id),
        )
        return self._serialize_one(saved)

    def _validated_branch_ids(self, branch_ids: list[str]) -> list[str]:
        validated: list[str] = []
        for branch_id in sorted(set(branch_ids)):
            if self.branch_repository.get_by_id(branch_id) is None:
                raise NotFoundException(
                    code='branch_not_found',
                    message='Branch was not found.',
                    details=[{'field': 'branch_ids', 'message': f'Branch {branch_id} was not found.'}],
                )
            validated.append(branch_id)
        return validated

    def _get_promotion_or_404(self, promotion_id: str) -> Promotion:
        promotion = self.repository.get_by_id(promotion_id)
        if promotion is None:
            raise NotFoundException(
                code='promotion_not_found',
                message='Promotion was not found.',
            )
        return promotion

    def _ensure_branch_exists(self, branch_id: str) -> None:
        if self.branch_repository.get_by_id(branch_id) is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Branch was not found.',
            )

    def _serialize_many(self, promotions: list[Promotion]) -> list[AdminPromotionResponse]:
        branch_ids_map = self.repository.get_branch_ids_map([promotion.id for promotion in promotions])
        return [
            AdminPromotionResponse(
                id=promotion.id,
                title=promotion.title,
                description=promotion.description,
                badge_label=promotion.badge_label,
                image_url=promotion.image_url,
                branch_ids=branch_ids_map.get(promotion.id, []),
                cta_label=promotion.cta_label,
                display_order=promotion.display_order,
                is_active=promotion.is_active,
                is_published=promotion.is_published,
            )
            for promotion in promotions
        ]

    def _serialize_one(self, promotion: Promotion) -> AdminPromotionResponse:
        return self._serialize_many([promotion])[0]
