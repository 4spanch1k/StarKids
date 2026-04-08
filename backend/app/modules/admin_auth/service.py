from ...core.security.tokens import generate_placeholder_token_pair
from .schemas import AdminLoginRequest, AdminLoginResponse


class AdminAuthService:
    def login(self, payload: AdminLoginRequest) -> AdminLoginResponse:
        _ = payload
        tokens = generate_placeholder_token_pair('admin')
        return AdminLoginResponse(
            access_token=tokens.access_token,
            refresh_token=tokens.refresh_token,
            role='super_admin',
        )

