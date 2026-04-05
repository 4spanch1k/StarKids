from uuid import uuid4

from ...core.security.tokens import generate_placeholder_token_pair
from .schemas import OTPRequest, OTPRequestResponse, OTPVerifyRequest, TokenResponse


class MobileAuthService:
    def request_otp(self, payload: OTPRequest) -> OTPRequestResponse:
        _ = payload
        return OTPRequestResponse(
            verification_id=f'otp_{uuid4().hex}',
            expires_in_seconds=300,
        )

    def verify_otp(self, payload: OTPVerifyRequest) -> TokenResponse:
        _ = payload
        tokens = generate_placeholder_token_pair('mobile')
        return TokenResponse(
            access_token=tokens.access_token,
            refresh_token=tokens.refresh_token,
        )

