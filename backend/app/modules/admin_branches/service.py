from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.branch import Branch
from ...db.repositories.branch_menu_repository import BranchMenuRepository
from ...db.repositories.branch_pricing_repository import BranchPricingRepository
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.branch_ticket_repository import BranchTicketRepository
from ..branches.menu_seed import DEFAULT_BRANCH_MENU
from ..branches.ticket_seed import DEFAULT_BRANCH_TICKET_CONFIG
from .schemas import (
    AdminBranchContactsResponse,
    AdminBranchContactsUpdateRequest,
    AdminBranchCreateRequest,
    AdminBranchDetailResponse,
    AdminBranchGalleryResponse,
    AdminBranchGalleryUpdateRequest,
    AdminBranchListQuery,
    AdminBranchMenuCategoryResponse,
    AdminBranchMenuItemResponse,
    AdminBranchMenuResponse,
    AdminBranchMenuUpsertRequest,
    AdminBranchPricesRulesResponse,
    AdminBranchPricesRulesUpsertRequest,
    AdminBranchRuleResponse,
    AdminBranchSummaryResponse,
    AdminBranchTariffResponse,
    AdminBranchTicketItemResponse,
    AdminBranchTicketNoteResponse,
    AdminBranchTicketsResponse,
    AdminBranchTicketsUpsertRequest,
    AdminBranchUpdateRequest,
)

BRANCH_ADMIN_ALLOWED_ROLES = ('super_admin', 'content_manager')


class AdminBranchService:
    def __init__(
        self,
        *,
        repository: BranchRepository | None = None,
        pricing_repository: BranchPricingRepository | None = None,
        menu_repository: BranchMenuRepository | None = None,
        ticket_repository: BranchTicketRepository | None = None,
    ) -> None:
        self.repository = repository or BranchRepository()
        self.pricing_repository = pricing_repository or BranchPricingRepository()
        self.menu_repository = menu_repository or BranchMenuRepository()
        self.ticket_repository = ticket_repository or BranchTicketRepository()

    def list_branches(self, query: AdminBranchListQuery) -> list[AdminBranchSummaryResponse]:
        return [
            AdminBranchSummaryResponse.model_validate(branch)
            for branch in self.repository.list_all(include_inactive=query.include_inactive)
        ]

    def get_branch(self, branch_id: str) -> AdminBranchDetailResponse:
        branch = self._get_branch_or_404(branch_id)
        return AdminBranchDetailResponse.model_validate(branch)

    def create_branch(self, payload: AdminBranchCreateRequest) -> AdminBranchDetailResponse:
        self._ensure_slug_available(payload.slug)
        branch = self.repository.create(payload.model_dump())
        self._ensure_branch_menu_seeded(branch.id)
        self._ensure_branch_tickets_seeded(branch.id)
        return AdminBranchDetailResponse.model_validate(branch)

    def update_branch(
        self,
        branch_id: str,
        payload: AdminBranchUpdateRequest,
    ) -> AdminBranchDetailResponse:
        branch = self._get_branch_or_404(branch_id)
        changes = payload.model_dump(exclude_unset=True)
        if not changes:
            return AdminBranchDetailResponse.model_validate(branch)

        if 'slug' in changes:
            self._ensure_slug_available(changes['slug'], exclude_id=branch.id)

        for key, value in changes.items():
            setattr(branch, key, value)

        saved = self.repository.save(branch)
        return AdminBranchDetailResponse.model_validate(saved)

    def get_branch_contacts(self, branch_id: str) -> AdminBranchContactsResponse:
        branch = self._get_branch_or_404(branch_id)
        return self._serialize_contacts(branch)

    def update_branch_contacts(
        self,
        branch_id: str,
        payload: AdminBranchContactsUpdateRequest,
    ) -> AdminBranchContactsResponse:
        branch = self._get_branch_or_404(branch_id)
        branch.address = payload.address
        branch.phone = payload.phone
        branch.whatsapp_phone = payload.whatsapp_phone
        branch.map_url = payload.map_url
        branch.route_label = payload.route_label
        branch.parking_hint = payload.parking_hint
        branch.arrival_hint = payload.arrival_hint
        saved = self.repository.save(branch)
        return self._serialize_contacts(saved)

    def get_branch_gallery(self, branch_id: str) -> AdminBranchGalleryResponse:
        branch = self._get_branch_or_404(branch_id)
        return self._serialize_gallery(branch)

    def update_branch_gallery(
        self,
        branch_id: str,
        payload: AdminBranchGalleryUpdateRequest,
    ) -> AdminBranchGalleryResponse:
        branch = self._get_branch_or_404(branch_id)
        branch.hero_image_url = payload.hero_image_url
        branch.gallery_image_urls = payload.gallery_image_urls
        saved = self.repository.save(branch)
        return self._serialize_gallery(saved)

    def get_branch_prices_rules(self, branch_id: str) -> AdminBranchPricesRulesResponse:
        branch = self._get_branch_or_404(branch_id)
        profile = self.pricing_repository.get_profile(branch.id)
        if profile is None:
            raise NotFoundException(
                code='branch_prices_rules_not_found',
                message='Branch prices and rules were not found.',
            )
        tariffs = self.pricing_repository.list_tariffs(branch.id, active_only=False)
        rules = self.pricing_repository.list_rules(branch.id, active_only=False)
        return AdminBranchPricesRulesResponse(
            branch_id=branch.id,
            intro_title=profile.intro_title,
            intro_description=profile.intro_description,
            birthday_note=profile.birthday_note,
            disclaimer=profile.disclaimer,
            visit_tariffs=[
                AdminBranchTariffResponse(
                    id=tariff.id,
                    title=tariff.title,
                    price_label=tariff.price_label,
                    description=tariff.description,
                    display_order=tariff.display_order,
                    is_active=tariff.is_active,
                )
                for tariff in tariffs
            ],
            rules=[
                AdminBranchRuleResponse(
                    id=rule.id,
                    text=rule.text,
                    display_order=rule.display_order,
                    is_active=rule.is_active,
                )
                for rule in rules
            ],
        )

    def upsert_branch_prices_rules(
        self,
        branch_id: str,
        payload: AdminBranchPricesRulesUpsertRequest,
    ) -> AdminBranchPricesRulesResponse:
        branch = self._get_branch_or_404(branch_id)
        self.pricing_repository.replace_branch_pricing(
            branch_id=branch.id,
            profile_payload={
                'intro_title': payload.intro_title,
                'intro_description': payload.intro_description,
                'birthday_note': payload.birthday_note,
                'disclaimer': payload.disclaimer,
            },
            tariff_payloads=[item.model_dump() for item in payload.visit_tariffs],
            rule_payloads=[item.model_dump() for item in payload.rules],
        )
        return self.get_branch_prices_rules(branch.id)

    def get_branch_menu(self, branch_id: str) -> AdminBranchMenuResponse:
        branch = self._get_branch_or_404(branch_id)
        self._ensure_branch_menu_seeded(branch.id)
        return self._serialize_admin_menu(branch.id)

    def upsert_branch_menu(
        self,
        branch_id: str,
        payload: AdminBranchMenuUpsertRequest,
    ) -> AdminBranchMenuResponse:
        branch = self._get_branch_or_404(branch_id)
        self._validate_branch_menu(payload)
        self.menu_repository.replace_branch_menu(
            branch_id=branch.id,
            category_payloads=[item.model_dump() for item in payload.categories],
            item_payloads=[item.model_dump() for item in payload.items],
        )
        return self._serialize_admin_menu(branch.id)

    def get_branch_tickets(self, branch_id: str) -> AdminBranchTicketsResponse:
        branch = self._get_branch_or_404(branch_id)
        self._ensure_branch_tickets_seeded(branch.id)
        return self._serialize_admin_tickets(branch.id)

    def upsert_branch_tickets(
        self,
        branch_id: str,
        payload: AdminBranchTicketsUpsertRequest,
    ) -> AdminBranchTicketsResponse:
        branch = self._get_branch_or_404(branch_id)
        self.ticket_repository.replace_branch_ticket_config(
            branch_id=branch.id,
            item_payloads=[
                {
                    **item.model_dump(),
                    'badge_labels': [label.strip() for label in item.badge_labels if label.strip()],
                    'description': item.description.strip() if item.description else None,
                }
                for item in payload.items
            ],
            note_payloads=[
                {
                    **item.model_dump(),
                    'text': item.text.strip(),
                }
                for item in payload.notes
            ],
        )
        return self._serialize_admin_tickets(branch.id)

    def _get_branch_or_404(self, branch_id: str) -> Branch:
        branch = self.repository.get_by_id(branch_id)
        if branch is None:
            raise NotFoundException(
                code='branch_not_found',
                message='Branch was not found.',
            )
        return branch

    def _ensure_slug_available(
        self,
        slug: str,
        *,
        exclude_id: str | None = None,
    ) -> None:
        if self.repository.slug_exists(slug, exclude_id=exclude_id):
            raise DomainHTTPException(
                code='branch_slug_taken',
                message='Branch slug is already in use.',
                status_code=422,
                details=[{'field': 'slug', 'message': 'Branch slug is already in use.'}],
            )

    def _serialize_contacts(self, branch: Branch) -> AdminBranchContactsResponse:
        return AdminBranchContactsResponse(
            branch_id=branch.id,
            address=branch.address,
            phone=branch.phone,
            whatsapp_phone=branch.whatsapp_phone,
            map_url=branch.map_url,
            route_label=branch.route_label,
            parking_hint=branch.parking_hint,
            arrival_hint=branch.arrival_hint,
        )

    def _serialize_gallery(self, branch: Branch) -> AdminBranchGalleryResponse:
        return AdminBranchGalleryResponse(
            branch_id=branch.id,
            hero_image_url=branch.hero_image_url,
            gallery_image_urls=branch.gallery_image_urls,
        )

    def _serialize_admin_menu(self, branch_id: str) -> AdminBranchMenuResponse:
        categories = self.menu_repository.list_categories(branch_id, active_only=False)
        items = self.menu_repository.list_items(branch_id, active_only=False)
        categories_by_id = {category.id: category for category in categories}

        return AdminBranchMenuResponse(
            branch_id=branch_id,
            categories=[
                AdminBranchMenuCategoryResponse(
                    id=category.id,
                    key=category.key,
                    title=category.title,
                    display_order=category.display_order,
                    is_active=category.is_active,
                )
                for category in categories
            ],
            items=[
                AdminBranchMenuItemResponse(
                    id=item.id,
                    title=item.title,
                    price_tenge=item.price_tenge,
                    image_url=item.image_url,
                    category_key=categories_by_id[item.category_id].key,
                    display_order=item.display_order,
                    is_active=item.is_active,
                )
                for item in items
                if item.category_id in categories_by_id
            ],
        )

    def _ensure_branch_menu_seeded(self, branch_id: str) -> None:
        if self.menu_repository.has_menu(branch_id):
            return
        self.menu_repository.replace_branch_menu(
            branch_id=branch_id,
            category_payloads=DEFAULT_BRANCH_MENU['categories'],
            item_payloads=DEFAULT_BRANCH_MENU['items'],
        )

    def _ensure_branch_tickets_seeded(self, branch_id: str) -> None:
        if self.ticket_repository.has_ticket_config(branch_id):
            return
        self.ticket_repository.replace_branch_ticket_config(
            branch_id=branch_id,
            item_payloads=DEFAULT_BRANCH_TICKET_CONFIG['items'],
            note_payloads=DEFAULT_BRANCH_TICKET_CONFIG['notes'],
        )

    def _validate_branch_menu(self, payload: AdminBranchMenuUpsertRequest) -> None:
        normalized_keys = [item.key.strip() for item in payload.categories]
        unique_keys = {item for item in normalized_keys if item}
        if len(unique_keys) != len(normalized_keys):
            raise DomainHTTPException(
                code='branch_menu_duplicate_category_key',
                message='Branch menu category keys must be unique.',
                status_code=422,
                details=[
                    {
                        'field': 'categories',
                        'message': 'Категории меню должны иметь уникальные ключи.',
                    }
                ],
            )

        missing_keys = sorted(
            {
                item.category_key
                for item in payload.items
                if item.category_key not in unique_keys
            }
        )
        if missing_keys:
            raise DomainHTTPException(
                code='branch_menu_invalid_category_key',
                message='Branch menu item references an unknown category key.',
                status_code=422,
                details=[
                    {
                        'field': 'items',
                        'message': 'Для позиции меню выбрана несуществующая категория.',
                    }
                ],
            )

    def _serialize_admin_tickets(self, branch_id: str) -> AdminBranchTicketsResponse:
        items = self.ticket_repository.list_items(branch_id, active_only=False)
        notes = self.ticket_repository.list_notes(branch_id, active_only=False)

        return AdminBranchTicketsResponse(
            branch_id=branch_id,
            items=[
                AdminBranchTicketItemResponse(
                    id=item.id,
                    title=item.title,
                    description=item.description,
                    price_tenge=item.price_tenge,
                    badge_labels=item.badge_labels or [],
                    display_order=item.display_order,
                    is_active=item.is_active,
                )
                for item in items
            ],
            notes=[
                AdminBranchTicketNoteResponse(
                    id=note.id,
                    text=note.text,
                    display_order=note.display_order,
                    is_active=note.is_active,
                )
                for note in notes
            ],
        )
