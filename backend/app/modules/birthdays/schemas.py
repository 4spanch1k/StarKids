from pydantic import BaseModel, ConfigDict, Field


class BirthdayPackageSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    slug: str
    branch_id: str
    name: str
    price_from: int
    price_label: str
    guest_capacity_label: str
    image_url: str | None = None
    is_featured: bool


class BirthdayPackageDetail(BirthdayPackageSummary):
    description: str
    highlights: list[str] = Field(default_factory=list)
