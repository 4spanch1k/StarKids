from collections.abc import Sequence

from sqlalchemy import delete, select

from ..models.promotion import Promotion
from ..models.promotion_branch import PromotionBranch
from .base import Repository


class PromotionRepository(Repository):
    def list_admin(
        self,
        *,
        branch_id: str | None = None,
        is_active: bool | None = None,
        is_published: bool | None = None,
    ) -> list[Promotion]:
        statement = select(Promotion)
        if branch_id:
            promotion_ids = select(PromotionBranch.promotion_id).where(
                PromotionBranch.branch_id == branch_id,
            )
            statement = statement.where(Promotion.id.in_(promotion_ids))
        if is_active is not None:
            statement = statement.where(Promotion.is_active.is_(is_active))
        if is_published is not None:
            statement = statement.where(Promotion.is_published.is_(is_published))
        statement = statement.order_by(Promotion.display_order.asc(), Promotion.title.asc())
        return list(self.db.scalars(statement).all())

    def list_mobile(
        self,
        *,
        branch_id: str | None = None,
    ) -> list[Promotion]:
        return self.list_admin(
            branch_id=branch_id,
            is_active=True,
            is_published=True,
        )

    def get_by_id(self, promotion_id: str) -> Promotion | None:
        statement = select(Promotion).where(Promotion.id == promotion_id)
        return self.db.scalar(statement)

    def create(
        self,
        *,
        payload: dict[str, object],
        branch_ids: Sequence[str],
    ) -> Promotion:
        promotion = Promotion(**payload)
        self.db.add(promotion)
        self.db.flush()
        self._replace_branch_links(promotion.id, branch_ids)
        self.db.commit()
        self.db.refresh(promotion)
        return promotion

    def save(
        self,
        *,
        promotion: Promotion,
        branch_ids: Sequence[str],
    ) -> Promotion:
        self.db.add(promotion)
        self.db.flush()
        self._replace_branch_links(promotion.id, branch_ids)
        self.db.commit()
        self.db.refresh(promotion)
        return promotion

    def get_branch_ids(self, promotion_id: str) -> list[str]:
        statement = (
            select(PromotionBranch.branch_id)
            .where(PromotionBranch.promotion_id == promotion_id)
            .order_by(PromotionBranch.branch_id.asc())
        )
        return list(self.db.scalars(statement).all())

    def get_branch_ids_map(
        self,
        promotion_ids: Sequence[str],
    ) -> dict[str, list[str]]:
        if not promotion_ids:
            return {}

        statement = select(PromotionBranch).where(
            PromotionBranch.promotion_id.in_(promotion_ids),
        )
        rows = self.db.scalars(statement).all()
        result: dict[str, list[str]] = {promotion_id: [] for promotion_id in promotion_ids}
        for row in rows:
            result.setdefault(row.promotion_id, []).append(row.branch_id)
        for branch_ids in result.values():
            branch_ids.sort()
        return result

    def _replace_branch_links(
        self,
        promotion_id: str,
        branch_ids: Sequence[str],
    ) -> None:
        self.db.execute(
            delete(PromotionBranch).where(PromotionBranch.promotion_id == promotion_id),
        )
        for branch_id in sorted(set(branch_ids)):
            self.db.add(
                PromotionBranch(
                    promotion_id=promotion_id,
                    branch_id=branch_id,
                )
            )
