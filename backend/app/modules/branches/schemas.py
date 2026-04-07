from pydantic import BaseModel, ConfigDict, Field


class BranchSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    slug: str
    name: str
    city: str
    short_label: str
    address: str
    working_hours: str
    is_active: bool


class BranchDetail(BranchSummary):
    description: str
    phone: str
    whatsapp_phone: str
    hero_image_url: str | None = None
    gallery_image_urls: list[str] = Field(default_factory=list)
    facilities: list[str] = Field(default_factory=list)
