from collections.abc import Sequence

from sqlalchemy import delete, select

from ..models.branch_menu_category import BranchMenuCategory
from ..models.branch_menu_item import BranchMenuItem
from .base import Repository


class BranchMenuRepository(Repository):
    def has_menu(self, branch_id: str) -> bool:
        statement = select(BranchMenuCategory.id).where(
            BranchMenuCategory.branch_id == branch_id,
        )
        return self.db.scalar(statement) is not None

    def list_categories(
        self,
        branch_id: str,
        *,
        active_only: bool,
    ) -> list[BranchMenuCategory]:
        statement = select(BranchMenuCategory).where(
            BranchMenuCategory.branch_id == branch_id,
        )
        if active_only:
            statement = statement.where(BranchMenuCategory.is_active.is_(True))
        statement = statement.order_by(
            BranchMenuCategory.display_order.asc(),
            BranchMenuCategory.title.asc(),
        )
        return list(self.db.scalars(statement).all())

    def list_items(
        self,
        branch_id: str,
        *,
        active_only: bool,
    ) -> list[BranchMenuItem]:
        statement = select(BranchMenuItem).where(BranchMenuItem.branch_id == branch_id)
        if active_only:
            statement = statement.where(BranchMenuItem.is_active.is_(True))
        statement = statement.order_by(
            BranchMenuItem.display_order.asc(),
            BranchMenuItem.title.asc(),
        )
        return list(self.db.scalars(statement).all())

    def replace_branch_menu(
        self,
        *,
        branch_id: str,
        category_payloads: Sequence[dict[str, object]],
        item_payloads: Sequence[dict[str, object]],
    ) -> None:
        self.db.execute(delete(BranchMenuItem).where(BranchMenuItem.branch_id == branch_id))
        self.db.execute(
            delete(BranchMenuCategory).where(BranchMenuCategory.branch_id == branch_id)
        )

        category_ids_by_key: dict[str, str] = {}
        for payload in category_payloads:
            category = BranchMenuCategory(branch_id=branch_id, **payload)
            self.db.add(category)
            self.db.flush()
            category_ids_by_key[category.key] = category.id

        for payload in item_payloads:
            category_key = str(payload['category_key'])
            category_id = category_ids_by_key[category_key]
            item_payload = dict(payload)
            item_payload.pop('category_key')
            self.db.add(
                BranchMenuItem(
                    branch_id=branch_id,
                    category_id=category_id,
                    **item_payload,
                )
            )

        self.db.commit()
