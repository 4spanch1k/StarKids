from pydantic import BaseModel


class HomeSection(BaseModel):
    key: str
    title: str
    description: str


class HomeResponse(BaseModel):
    city: str
    sections: list[HomeSection]

