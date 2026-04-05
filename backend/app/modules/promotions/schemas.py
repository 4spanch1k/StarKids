from pydantic import BaseModel


class PromotionSummary(BaseModel):
    id: str
    title: str
    branch_id: str
    is_active: bool

