from pydantic import BaseModel, Field


class PromotionSummary(BaseModel):
    id: str
    title: str
    description: str
    badge_label: str
    image_url: str | None = None
    branch_ids: list[str] = Field(default_factory=list)
    cta_label: str
