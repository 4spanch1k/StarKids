from pydantic import BaseModel


class BranchSummary(BaseModel):
    id: str
    name: str
    city: str
    address: str
    is_active: bool

