from pydantic import BaseModel, Field


class AdminPromotionListQuery(BaseModel):
    branch_id: str | None = Field(default=None, min_length=1, max_length=32)
    is_active: bool | None = None
    is_published: bool | None = None


class AdminPromotionResponse(BaseModel):
    id: str
    title: str
    description: str
    badge_label: str
    image_url: str | None = None
    branch_ids: list[str] = Field(default_factory=list)
    cta_label: str
    display_order: int
    is_active: bool
    is_published: bool


class AdminPromotionCreateRequest(BaseModel):
    title: str = Field(min_length=2, max_length=255)
    description: str = Field(min_length=10, max_length=5000)
    badge_label: str = Field(min_length=1, max_length=64)
    image_url: str | None = Field(default=None, max_length=512)
    branch_ids: list[str] = Field(default_factory=list)
    cta_label: str = Field(min_length=1, max_length=64)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True
    is_published: bool = False


class AdminPromotionUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=255)
    description: str | None = Field(default=None, min_length=10, max_length=5000)
    badge_label: str | None = Field(default=None, min_length=1, max_length=64)
    image_url: str | None = Field(default=None, max_length=512)
    branch_ids: list[str] | None = None
    cta_label: str | None = Field(default=None, min_length=1, max_length=64)
    display_order: int | None = Field(default=None, ge=0, le=1000)
    is_active: bool | None = None
    is_published: bool | None = None
