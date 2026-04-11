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


class BranchContactsResponse(BaseModel):
    branch_id: str
    address: str
    phone: str
    whatsapp_phone: str
    map_url: str
    route_label: str
    parking_hint: str | None = None
    arrival_hint: str | None = None


class BranchGalleryResponse(BaseModel):
    branch_id: str
    hero_image_url: str | None = None
    gallery_image_urls: list[str] = Field(default_factory=list)


class BranchVisitTariffResponse(BaseModel):
    id: str
    title: str
    price_label: str
    description: str


class BranchPricesRulesResponse(BaseModel):
    branch_id: str
    intro_title: str
    intro_description: str
    visit_tariffs: list[BranchVisitTariffResponse] = Field(default_factory=list)
    rules: list[str] = Field(default_factory=list)
    birthday_note: str
    disclaimer: str | None = None


class BranchMenuItemResponse(BaseModel):
    id: str
    title: str
    price_tenge: int
    image_url: str


class BranchMenuCategoryResponse(BaseModel):
    id: str
    title: str
    items: list[BranchMenuItemResponse] = Field(default_factory=list)


class BranchMenuResponse(BaseModel):
    branch_id: str
    categories: list[BranchMenuCategoryResponse] = Field(default_factory=list)
