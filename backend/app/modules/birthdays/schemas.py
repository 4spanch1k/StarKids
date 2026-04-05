from pydantic import BaseModel


class BirthdayPackageSummary(BaseModel):
    id: str
    name: str
    price_from: int
    branch_id: str

