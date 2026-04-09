from pydantic import BaseModel, ConfigDict, Field


class AdminBirthdayPackageListQuery(BaseModel):
    branch_id: str | None = Field(default=None, min_length=1, max_length=32)
    include_inactive: bool = False


class AdminBirthdayPackageSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    branch_id: str
    slug: str
    name: str
    price_from: int
    price_label: str
    guest_capacity_label: str
    image_url: str | None = None
    is_featured: bool
    is_active: bool
    display_order: int


class AdminBirthdayPackageDetailResponse(AdminBirthdayPackageSummaryResponse):
    description: str
    highlights: list[str] = Field(default_factory=list)


class AdminBirthdayPackageCreateRequest(BaseModel):
    branch_id: str = Field(min_length=1, max_length=32)
    slug: str = Field(min_length=2, max_length=120)
    name: str = Field(min_length=2, max_length=255)
    price_from: int = Field(ge=0, le=10_000_000)
    price_label: str = Field(min_length=1, max_length=64)
    guest_capacity_label: str = Field(min_length=1, max_length=64)
    description: str = Field(min_length=10, max_length=5000)
    highlights: list[str] = Field(default_factory=list)
    image_url: str | None = Field(default=None, max_length=512)
    is_featured: bool = False
    is_active: bool = True
    display_order: int = Field(default=0, ge=0, le=1000)


class AdminBirthdayPackageUpdateRequest(BaseModel):
    branch_id: str | None = Field(default=None, min_length=1, max_length=32)
    slug: str | None = Field(default=None, min_length=2, max_length=120)
    name: str | None = Field(default=None, min_length=2, max_length=255)
    price_from: int | None = Field(default=None, ge=0, le=10_000_000)
    price_label: str | None = Field(default=None, min_length=1, max_length=64)
    guest_capacity_label: str | None = Field(default=None, min_length=1, max_length=64)
    description: str | None = Field(default=None, min_length=10, max_length=5000)
    highlights: list[str] | None = None
    image_url: str | None = Field(default=None, max_length=512)
    is_featured: bool | None = None
    is_active: bool | None = None
    display_order: int | None = Field(default=None, ge=0, le=1000)
