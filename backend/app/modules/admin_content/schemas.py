from pydantic import BaseModel, Field


class AdminFAQListQuery(BaseModel):
    is_active: bool | None = None
    is_published: bool | None = None


class AdminFAQResponse(BaseModel):
    id: str
    question: str
    answer: str
    display_order: int
    is_active: bool
    is_published: bool


class AdminFAQCreateRequest(BaseModel):
    question: str = Field(min_length=4, max_length=255)
    answer: str = Field(min_length=4, max_length=5000)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True
    is_published: bool = False


class AdminFAQUpdateRequest(BaseModel):
    question: str | None = Field(default=None, min_length=4, max_length=255)
    answer: str | None = Field(default=None, min_length=4, max_length=5000)
    display_order: int | None = Field(default=None, ge=0, le=1000)
    is_active: bool | None = None
    is_published: bool | None = None


class AdminContentBlockListQuery(BaseModel):
    surface: str | None = Field(default=None, min_length=1, max_length=64)
    is_active: bool | None = None
    is_published: bool | None = None


class AdminContentBlockResponse(BaseModel):
    id: str
    surface: str
    key: str
    title: str
    body: str
    cta_label: str | None = None
    display_order: int
    is_active: bool
    is_published: bool


class AdminContentBlockCreateRequest(BaseModel):
    surface: str = Field(min_length=1, max_length=64)
    key: str = Field(min_length=1, max_length=64)
    title: str = Field(min_length=2, max_length=255)
    body: str = Field(min_length=2, max_length=5000)
    cta_label: str | None = Field(default=None, max_length=64)
    display_order: int = Field(default=0, ge=0, le=1000)
    is_active: bool = True
    is_published: bool = False


class AdminContentBlockUpdateRequest(BaseModel):
    surface: str | None = Field(default=None, min_length=1, max_length=64)
    key: str | None = Field(default=None, min_length=1, max_length=64)
    title: str | None = Field(default=None, min_length=2, max_length=255)
    body: str | None = Field(default=None, min_length=2, max_length=5000)
    cta_label: str | None = Field(default=None, max_length=64)
    display_order: int | None = Field(default=None, ge=0, le=1000)
    is_active: bool | None = None
    is_published: bool | None = None
