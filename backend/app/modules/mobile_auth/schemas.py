from pydantic import BaseModel, EmailStr, Field


class OTPRequest(BaseModel):
    phone: str = Field(min_length=8, max_length=20)


class OTPRequestResponse(BaseModel):
    verification_id: str
    expires_in_seconds: int


class OTPVerifyRequest(BaseModel):
    phone: str = Field(min_length=8, max_length=20)
    code: str = Field(min_length=4, max_length=8, pattern=r'^\d{4,8}$')
    verification_id: str = Field(min_length=1)


class MobileEmailAuthRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class MobileRefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class MobileCurrentUserResponse(BaseModel):
    id: str
    phone: str | None = None
    email: EmailStr | None = None


class MobileAuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = 'bearer'
    expires_in_seconds: int
    refresh_expires_in_seconds: int
    user: MobileCurrentUserResponse
