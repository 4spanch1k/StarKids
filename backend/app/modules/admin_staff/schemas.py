from pydantic import BaseModel, Field


class AdminStaffBranchUpdateRequest(BaseModel):
    branch_id: str | None = Field(default=None, max_length=32)


class AdminStaffResponse(BaseModel):
    id: str
    email: str
    full_name: str
    role: str
    is_active: bool
    branch_id: str | None = None
    branch_name: str | None = None


class AdminStaffListResponse(BaseModel):
    items: list[AdminStaffResponse]
