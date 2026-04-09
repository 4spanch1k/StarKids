from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.branch import Branch
from ...db.repositories.branch_pricing_repository import BranchPricingRepository
from ...db.repositories.branch_repository import BranchRepository
from .schemas import (
    AdminBranchContactsResponse,
    AdminBranchContactsUpdateRequest,
    AdminBranchCreateRequest,
    AdminBranchDetailResponse,
    AdminBranchGalleryResponse,
    AdminBranchGalleryUpdateRequest,
    AdminBranchListQuery,
    AdminBranchPricesRulesResponse,
    AdminBranchPricesRulesUpsertRequest,
    AdminBranchRuleResponse,
    AdminBranchSummaryResponse,
    AdminBranchTariffResponse,
    AdminBranchUpdateRequest,
)

BRANCH_ADMIN_ALLOWED_ROLES = ('super_admin', 'content_manager')


class AdminBranchService:
    def __init__(
        self,
        *,
        repository: BranchRepository | None = None,
        pricing_repository: BranchPricingRepository | None = None,
    ) -> None:
        self.repository = repository or BranchRepository()
        self.pricing_repository = pricing_repository or BranchPricingRepository()

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
