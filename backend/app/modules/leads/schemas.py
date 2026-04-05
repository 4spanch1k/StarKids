from pydantic import BaseModel, EmailStr


class ContactLeadCreate(BaseModel):
    name: str
    phone: str
    message: str | None = None
    email: EmailStr | None = None


class BirthdayLeadCreate(BaseModel):
    customer_name: str
    phone: str
    branch_id: str
    preferred_date: str | None = None
    guest_count: int | None = None
    notes: str | None = None


class LeadCreatedResponse(BaseModel):
    id: str
    type: str
    status: str

