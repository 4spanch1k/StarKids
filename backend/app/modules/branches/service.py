from ...core.exceptions.http import NotFoundException
from ...core.config.settings import Settings, get_settings
from ...db.repositories.branch_menu_repository import BranchMenuRepository
from ...db.repositories.branch_pricing_repository import BranchPricingRepository
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.branch_ticket_repository import BranchTicketRepository
from .menu_seed import DEFAULT_BRANCH_MENU
from .ticket_seed import DEFAULT_BRANCH_TICKET_CONFIG
from .schemas import (
    BranchContactsResponse,
    BranchDetail,
    BranchGalleryResponse,
    BranchMenuCategoryResponse,
    BranchMenuItemResponse,
    BranchMenuResponse,
    BranchPricesRulesResponse,
    BranchSummary,
    BranchTicketItemResponse,
    BranchTicketsResponse,
    BranchVisitTariffResponse,
)


class BranchService:
    def __init__(
        self,
        repository: BranchRepository | None = None,
        pricing_repository: BranchPricingRepository | None = None,
        menu_repository: BranchMenuRepository | None = None,
        ticket_repository: BranchTicketRepository | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.repository = repository or BranchRepository()
        self.pricing_repository = pricing_repository or BranchPricingRepository()
        self.menu_repository = menu_repository or BranchMenuRepository()
        self.ticket_repository = ticket_repository or BranchTicketRepository()
        self.settings = settings or get_settings()

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

    def get_branch_tickets(self, branch_id_or_slug: str) -> BranchTicketsResponse:
        branch = self._get_active_branch_or_404(branch_id_or_slug)
        self._ensure_branch_tickets_seeded(branch.id)
        items = self.ticket_repository.list_items(branch.id, active_only=True)
        notes = self.ticket_repository.list_notes(branch.id, active_only=True)

        return BranchTicketsResponse(
            branch_id=branch.id,
            items=[
                BranchTicketItemResponse(
                    id=item.id,
                    title=item.title,
                    description=item.description,
                    price_tenge=item.price_tenge,
                    badge_labels=item.badge_labels or [],
                )
                for item in items
            ],
            notes=[note.text for note in notes],
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
        if not self.settings.development_seed_enabled:
            return
        if self.menu_repository.has_menu(branch_id):
            return
        self.menu_repository.replace_branch_menu(
            branch_id=branch_id,
            category_payloads=DEFAULT_BRANCH_MENU['categories'],
            item_payloads=DEFAULT_BRANCH_MENU['items'],
        )

    def _ensure_branch_tickets_seeded(self, branch_id: str) -> None:
        if not self.settings.development_seed_enabled:
            return
        if self.ticket_repository.has_ticket_config(branch_id):
            return
        self.ticket_repository.replace_branch_ticket_config(
            branch_id=branch_id,
            item_payloads=DEFAULT_BRANCH_TICKET_CONFIG['items'],
            note_payloads=DEFAULT_BRANCH_TICKET_CONFIG['notes'],
        )
