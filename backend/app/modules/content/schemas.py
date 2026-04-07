from pydantic import BaseModel, Field


class ContentBlockListQuery(BaseModel):
    surface: str = Field(min_length=1, max_length=64)


class FAQResponse(BaseModel):
    id: str
    question: str
    answer: str


class ContentBlockResponse(BaseModel):
    id: str
    surface: str
    key: str
    title: str
    body: str
    cta_label: str | None = None
