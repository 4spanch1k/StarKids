from pydantic import BaseModel, ConfigDict, Field

PHONE_PATTERN = r'^\+?[0-9()\- ]{10,20}$'


class AdminBranchListQuery(BaseModel):
    include_inactive: bool = False


class AdminBranchSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    slug: str
    name: str
    city: str
    short_label: str
    working_hours: str
    display_order: int
    is_active: bool


class AdminBranchDetailResponse(AdminBranchSummaryResponse):
    address: str
    description: str
    phone: str
    whatsapp_phone: str
    map_url: str | None = None
    route_label: str | None = None
    parking_hint: str | None = None
    arrival_hint: str | None = None
    hero_image_url: str | None = None
    gallery_image_urls: list[str] = Field(default_factory=list)
    facilities: list[str] = Field(default_factory=list)


class AdminBranchCreateRequest(BaseModel):
    slug: str = Field(min_length=2, max_length=120)
    name: str = Field(min_length=2, max_length=255)
    city: str = Field(min_length=2, max_length=120)
    address: str = Field(min_length=4, max_length=255)
    short_label: str = Field(min_length=2, max_length=120)
    working_hours: str = Field(min_length=2, max_length=255)
    description: str = Field(min_length=10, max_length=5000)
    phone: str = Field(min_length=10, max_length=20, pattern=PHONE_PATTERN)
    whatsapp_phone: str = Field(min_length=10, max_length=20, pattern=PHONE_PATTERN)
    map_url: str | None = Field(default=None, max_length=1024)
    route_label: str | None = Field(default=None, max_length=255)
    parking_hint: str | None = Field(default=None, max_length=1000)
    arrival_hint: str | None = Field(default=None, max_length=1000)
    hero_image_url: str | None = Field(default=None, max_length=512)
    gallery_image_urls: list[str] = Field(default_factory=list)
    facilities: list[str] = Field(default_factory=list)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True


class AdminBranchUpdateRequest(BaseModel):
    slug: str | None = Field(default=None, min_length=2, max_length=120)
    name: str | None = Field(default=None, min_length=2, max_length=255)
    city: str | None = Field(default=None, min_length=2, max_length=120)
    address: str | None = Field(default=None, min_length=4, max_length=255)
    short_label: str | None = Field(default=None, min_length=2, max_length=120)
    working_hours: str | None = Field(default=None, min_length=2, max_length=255)
    description: str | None = Field(default=None, min_length=10, max_length=5000)
    phone: str | None = Field(default=None, min_length=10, max_length=20, pattern=PHONE_PATTERN)
    whatsapp_phone: str | None = Field(
        default=None,
        min_length=10,
        max_length=20,
        pattern=PHONE_PATTERN,
    )
    map_url: str | None = Field(default=None, max_length=1024)
    route_label: str | None = Field(default=None, max_length=255)
    parking_hint: str | None = Field(default=None, max_length=1000)
    arrival_hint: str | None = Field(default=None, max_length=1000)
    hero_image_url: str | None = Field(default=None, max_length=512)
    gallery_image_urls: list[str] | None = None
    facilities: list[str] | None = None
    display_order: int | None = Field(default=None, ge=0, le=1000)
    is_active: bool | None = None


class AdminBranchContactsResponse(BaseModel):
    branch_id: str
    address: str
    phone: str
    whatsapp_phone: str
    map_url: str | None = None
    route_label: str | None = None
    parking_hint: str | None = None
    arrival_hint: str | None = None


class AdminBranchContactsUpdateRequest(BaseModel):
    address: str = Field(min_length=4, max_length=255)
    phone: str = Field(min_length=10, max_length=20, pattern=PHONE_PATTERN)
    whatsapp_phone: str = Field(min_length=10, max_length=20, pattern=PHONE_PATTERN)
    map_url: str = Field(min_length=8, max_length=1024)
    route_label: str = Field(min_length=2, max_length=255)
    parking_hint: str | None = Field(default=None, max_length=1000)
    arrival_hint: str | None = Field(default=None, max_length=1000)


class AdminBranchGalleryResponse(BaseModel):
    branch_id: str
    hero_image_url: str | None = None
    gallery_image_urls: list[str] = Field(default_factory=list)


class AdminBranchGalleryUpdateRequest(BaseModel):
    hero_image_url: str | None = Field(default=None, max_length=512)
    gallery_image_urls: list[str] = Field(default_factory=list)


class AdminBranchTariffInput(BaseModel):
    title: str = Field(min_length=2, max_length=255)
    price_label: str = Field(min_length=1, max_length=64)
    description: str = Field(min_length=2, max_length=2000)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True


class AdminBranchRuleInput(BaseModel):
    text: str = Field(min_length=2, max_length=1000)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True


class AdminBranchTariffResponse(AdminBranchTariffInput):
    id: str


class AdminBranchRuleResponse(AdminBranchRuleInput):
    id: str


class AdminBranchPricesRulesResponse(BaseModel):
    branch_id: str
    intro_title: str
    intro_description: str
    birthday_note: str
    disclaimer: str | None = None
    visit_tariffs: list[AdminBranchTariffResponse] = Field(default_factory=list)
    rules: list[AdminBranchRuleResponse] = Field(default_factory=list)


class AdminBranchPricesRulesUpsertRequest(BaseModel):
    intro_title: str = Field(min_length=2, max_length=255)
    intro_description: str = Field(min_length=10, max_length=3000)
    birthday_note: str = Field(min_length=2, max_length=3000)
    disclaimer: str | None = Field(default=None, max_length=2000)
    visit_tariffs: list[AdminBranchTariffInput] = Field(default_factory=list)
    rules: list[AdminBranchRuleInput] = Field(default_factory=list)


class AdminBranchMenuCategoryInput(BaseModel):
    key: str = Field(min_length=1, max_length=64)
    title: str = Field(min_length=2, max_length=255)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True


class AdminBranchMenuItemInput(BaseModel):
    title: str = Field(min_length=2, max_length=255)
    price_tenge: int = Field(ge=0, le=1000000)
    image_url: str = Field(min_length=8, max_length=1024)
    category_key: str = Field(min_length=1, max_length=64)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True


class AdminBranchMenuCategoryResponse(AdminBranchMenuCategoryInput):
    id: str


class AdminBranchMenuItemResponse(AdminBranchMenuItemInput):
    id: str


class AdminBranchMenuResponse(BaseModel):
    branch_id: str
    categories: list[AdminBranchMenuCategoryResponse] = Field(default_factory=list)
    items: list[AdminBranchMenuItemResponse] = Field(default_factory=list)


class AdminBranchMenuUpsertRequest(BaseModel):
    categories: list[AdminBranchMenuCategoryInput] = Field(default_factory=list)
    items: list[AdminBranchMenuItemInput] = Field(default_factory=list)


class AdminBranchTicketItemInput(BaseModel):
    title: str = Field(min_length=2, max_length=255)
    description: str | None = Field(default=None, max_length=2000)
    price_tenge: int = Field(ge=0, le=1000000)
    badge_labels: list[str] = Field(default_factory=list)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True


class AdminBranchTicketNoteInput(BaseModel):
    text: str = Field(min_length=2, max_length=1000)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True


class AdminBranchTicketItemResponse(AdminBranchTicketItemInput):
    id: str


class AdminBranchTicketNoteResponse(AdminBranchTicketNoteInput):
    id: str


class AdminBranchTicketsResponse(BaseModel):
    branch_id: str
    items: list[AdminBranchTicketItemResponse] = Field(default_factory=list)
    notes: list[AdminBranchTicketNoteResponse] = Field(default_factory=list)


class AdminBranchTicketsUpsertRequest(BaseModel):
    items: list[AdminBranchTicketItemInput] = Field(default_factory=list)
    notes: list[AdminBranchTicketNoteInput] = Field(default_factory=list)
