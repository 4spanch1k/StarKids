from fastapi import APIRouter

from .schemas import AdminLoginRequest, AdminLoginResponse
from .service import AdminAuthService

router = APIRouter()
service = AdminAuthService()


@router.post('/login', response_model=AdminLoginResponse)
def login(payload: AdminLoginRequest) -> AdminLoginResponse:
    return service.login(payload)

