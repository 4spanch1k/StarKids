from ...core.exceptions.http import NotFoundException
from ...db.repositories.branch_menu_repository import BranchMenuRepository
from ...db.repositories.branch_pricing_repository import BranchPricingRepository
from ...db.repositories.branch_repository import BranchRepository
from .menu_seed import DEFAULT_BRANCH_MENU
from .schemas import (
    BranchContactsResponse,
    BranchDetail,
    BranchGalleryResponse,
    BranchMenuCategoryResponse,
    BranchMenuItemResponse,
    BranchMenuResponse,
    BranchPricesRulesResponse,
    BranchSummary,
    BranchVisitTariffResponse,
)


class BranchService:
    def __init__(
        self,
        repository: BranchRepository | None = None,
        pricing_repository: BranchPricingRepository | None = None,
        menu_repository: BranchMenuRepository | None = None,
    ) -> None:
        self.repository = repository or BranchRepository()
        self.pricing_repository = pricing_repository or BranchPricingRepository()
        self.menu_repository = menu_repository or BranchMenuRepository()

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

    def get_branch_contacts(self, branch_id_or_slug: str) -> BranchContactsResponse:
        branch = self._get_active_branch_or_404(branch_id_or_slug)
        if not branch.map_url or not branch.route_label:
            raise NotFoundException(
                code='branch_contacts_not_found',
                message='Branch contacts were not found.',
            )
        return BranchContactsResponse(
            branch_id=branch.id,
            address=branch.address,
            phone=branch.phone,
            whatsapp_phone=branch.whatsapp_phone,
            map_url=branch.map_url,
            route_label=branch.route_label,
            parking_hint=branch.parking_hint,
            arrival_hint=branch.arrival_hint,
        )

    def get_branch_gallery(self, branch_id_or_slug: str) -> BranchGalleryResponse:
        branch = self._get_active_branch_or_404(branch_id_or_slug)
        return BranchGalleryResponse(
            branch_id=branch.id,
            hero_image_url=branch.hero_image_url,
            gallery_image_urls=branch.gallery_image_urls,
        )

    def get_branch_prices_rules(self, branch_id_or_slug: str) -> BranchPricesRulesResponse:
        branch = self._get_active_branch_or_404(branch_id_or_slug)
        profile = self.pricing_repository.get_profile(branch.id)
        if profile is None:
            raise NotFoundException(
                code='branch_prices_rules_not_found',
                message='Branch prices and rules were not found.',
            )

        tariffs = self.pricing_repository.list_tariffs(branch.id, active_only=True)
        rules = self.pricing_repository.list_rules(branch.id, active_only=True)
        return BranchPricesRulesResponse(
            branch_id=branch.id,
            intro_title=profile.intro_title,
            intro_description=profile.intro_description,
            visit_tariffs=[
                BranchVisitTariffResponse(
                    id=tariff.id,
                    title=tariff.title,
                    price_label=tariff.price_label,
                    description=tariff.description,
                )
                for tariff in tariffs
            ],
            rules=[rule.text for rule in rules],
            birthday_note=profile.birthday_note,
            disclaimer=profile.disclaimer,
        )

    def get_branch_menu(self, branch_id_or_slug: str) -> BranchMenuResponse:
        branch = self._get_active_branch_or_404(branch_id_or_slug)
        self._ensure_branch_menu_seeded(branch.id)
        categories = self.menu_repository.list_categories(branch.id, active_only=True)
        items = self.menu_repository.list_items(branch.id, active_only=True)
        items_by_category_id: dict[str, list[BranchMenuItemResponse]] = {}

        for item in items:
            items_by_category_id.setdefault(item.category_id, []).append(
                BranchMenuItemResponse(
                    id=item.id,
                    title=item.title,
                    price_tenge=item.price_tenge,
                    image_url=item.image_url,
                )
            )

        return BranchMenuResponse(
            branch_id=branch.id,
            categories=[
                BranchMenuCategoryResponse(
                    id=category.id,
                    title=category.title,
                    items=items_by_category_id.get(category.id, []),
                )
                for category in categories
                if items_by_category_id.get(category.id)
            ],
        )

    def _get_active_branch_or_404(self, branch_id_or_slug: str):
        branch = self.repository.get_active_by_id_or_slug(branch_id_or_slug)
        if branch is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Branch was not found.',
            )
        return branch

    def _ensure_branch_menu_seeded(self, branch_id: str) -> None:
        if self.menu_repository.has_menu(branch_id):
            return
        self.menu_repository.replace_branch_menu(
            branch_id=branch_id,
            category_payloads=DEFAULT_BRANCH_MENU['categories'],
            item_payloads=DEFAULT_BRANCH_MENU['items'],
        )
