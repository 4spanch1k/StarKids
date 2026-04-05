from fastapi import APIRouter

from .schemas import OTPRequest, OTPRequestResponse, OTPVerifyRequest, TokenResponse
from .service import MobileAuthService

router = APIRouter()
service = MobileAuthService()


@router.post('/request-otp', response_model=OTPRequestResponse)
def request_otp(payload: OTPRequest) -> OTPRequestResponse:
    return service.request_otp(payload)


@router.post('/verify-otp', response_model=TokenResponse)
def verify_otp(payload: OTPVerifyRequest) -> TokenResponse:
    return service.verify_otp(payload)

