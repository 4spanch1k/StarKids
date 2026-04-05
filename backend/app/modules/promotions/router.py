from fastapi import APIRouter

from .schemas import PromotionSummary
from .service import PromotionsService

router = APIRouter()
service = PromotionsService()


@router.get('/promotions', response_model=list[PromotionSummary])
def list_promotions() -> list[PromotionSummary]:
    return service.list_promotions()

