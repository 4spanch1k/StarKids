from typing import Literal

from pydantic import BaseModel, EmailStr, Field


AdminRole = Literal[
    'super_admin',
    'operator',
    'content_manager',
    'sales_manager',
]


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
    captcha_id: str | None = Field(default=None, min_length=1)
    captcha_answer: str | None = Field(default=None, min_length=1, max_length=16)


class AdminRefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class AdminCurrentUserResponse(BaseModel):
    id: str
    email: EmailStr
    full_name: str
    role: AdminRole


class AdminAuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = 'bearer'
    expires_in_seconds: int
    refresh_expires_in_seconds: int
    user: AdminCurrentUserResponse
