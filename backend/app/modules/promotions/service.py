from .schemas import PromotionSummary


class PromotionsService:
    def list_promotions(self) -> list[PromotionSummary]:
        return [
            PromotionSummary(
                id='promo-weekday',
                title='Weekday family offer',
                branch_id='branch-1',
                is_active=True,
            ),
            PromotionSummary(
                id='promo-birthday',
                title='Birthday bonus package',
                branch_id='branch-2',
                is_active=True,
            ),
        ]

