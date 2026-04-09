from collections.abc import Sequence

from sqlalchemy import delete, select

from ..models.branch_pricing_profile import BranchPricingProfile
from ..models.branch_rule import BranchRule
from ..models.branch_tariff import BranchTariff
from .base import Repository


class BranchPricingRepository(Repository):
    def get_profile(self, branch_id: str) -> BranchPricingProfile | None:
        statement = select(BranchPricingProfile).where(
            BranchPricingProfile.branch_id == branch_id,
        )
        return self.db.scalar(statement)

    def list_tariffs(
        self,
        branch_id: str,
        *,
        active_only: bool,
    ) -> list[BranchTariff]:
        statement = select(BranchTariff).where(BranchTariff.branch_id == branch_id)
        if active_only:
            statement = statement.where(BranchTariff.is_active.is_(True))
        statement = statement.order_by(BranchTariff.display_order.asc(), BranchTariff.title.asc())
        return list(self.db.scalars(statement).all())

    def list_rules(
        self,
        branch_id: str,
        *,
        active_only: bool,
    ) -> list[BranchRule]:
        statement = select(BranchRule).where(BranchRule.branch_id == branch_id)
        if active_only:
            statement = statement.where(BranchRule.is_active.is_(True))
        statement = statement.order_by(BranchRule.display_order.asc(), BranchRule.id.asc())
        return list(self.db.scalars(statement).all())

    def replace_branch_pricing(
        self,
        *,
        branch_id: str,
        profile_payload: dict[str, object],
        tariff_payloads: Sequence[dict[str, object]],
        rule_payloads: Sequence[dict[str, object]],
    ) -> BranchPricingProfile:
        profile = self.get_profile(branch_id)
        if profile is None:
            profile = BranchPricingProfile(branch_id=branch_id, **profile_payload)
            self.db.add(profile)
        else:
            for key, value in profile_payload.items():
                setattr(profile, key, value)

        self.db.execute(delete(BranchTariff).where(BranchTariff.branch_id == branch_id))
        self.db.execute(delete(BranchRule).where(BranchRule.branch_id == branch_id))

        for payload in tariff_payloads:
            self.db.add(BranchTariff(branch_id=branch_id, **payload))

        for payload in rule_payloads:
            self.db.add(BranchRule(branch_id=branch_id, **payload))

        self.db.commit()
        self.db.refresh(profile)
        return profile
