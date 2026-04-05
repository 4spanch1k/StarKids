from pydantic import BaseModel


class OTPRequest(BaseModel):
    phone: str


class OTPRequestResponse(BaseModel):
    verification_id: str
    expires_in_seconds: int


class OTPVerifyRequest(BaseModel):
    phone: str
    code: str
    verification_id: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str

