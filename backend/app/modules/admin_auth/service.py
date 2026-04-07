from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from fastapi import status

from ...core.config.settings import Settings, get_settings
from ...core.exceptions.http import DomainHTTPException
from ...core.security.passwords import hash_password, verify_password
from ...core.security.tokens import (
    TokenPair,
    TokenPayload,
    TokenValidationError,
    create_admin_token_pair,
    decode_admin_token,
    hash_token_value,
)
from ...db.models.admin_session import AdminSession
from ...db.models.admin_user import AdminUser
from ...db.repositories.admin_session_repository import AdminSessionRepository
from ...db.repositories.admin_user_repository import AdminUserRepository
from .constants import ADMIN_ROLES, DEFAULT_ADMIN_ROLE
from .schemas import (
    AdminAuthResponse,
    AdminCurrentUserResponse,
    AdminLoginRequest,
    AdminRefreshRequest,
)


class AdminAuthService:
    def __init__(
        self,
        *,
        user_repository: AdminUserRepository | None = None,
        session_repository: AdminSessionRepository | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.user_repository = user_repository or AdminUserRepository()
        self.session_repository = session_repository or AdminSessionRepository()
        self.settings = settings or get_settings()

    def login(self, payload: AdminLoginRequest) -> AdminAuthResponse:
        self._ensure_runtime_configuration()
        self._ensure_bootstrap_admin()

        user = self.user_repository.find_by_email(str(payload.email))
        if user is None or not user.is_active:
            raise self.invalid_credentials_exception()
        if not verify_password(payload.password, user.password_hash):
            raise self.invalid_credentials_exception()
        if user.role not in ADMIN_ROLES:
            raise self.invalid_credentials_exception()

        token_pair = self._create_session_for_user(user)
        return self._build_auth_response(user, token_pair)

    def refresh(self, payload: AdminRefreshRequest) -> AdminAuthResponse:
        self._ensure_runtime_configuration()
        token_payload = self._decode_token(
            payload.refresh_token,
            expected_type='refresh',
        )
        user = self._get_active_user(token_payload.subject)
        session = self._get_active_session(token_payload.session_id)

        if session.admin_user_id != user.id:
            raise self.authentication_required_exception()
        if session.refresh_token_hash != hash_token_value(payload.refresh_token):
            raise self.authentication_required_exception()

        token_pair = self._rotate_session_for_user(user, session)
        return self._build_auth_response(user, token_pair)

    def get_current_user(self, access_token: str) -> AdminCurrentUserResponse:
        self._ensure_runtime_configuration()
        token_payload = self._decode_token(access_token, expected_type='access')
        user = self._get_active_user(token_payload.subject)
        session = self._get_active_session(token_payload.session_id)
        if session.admin_user_id != user.id:
            raise self.authentication_required_exception()
        return self._serialize_user(user)

    @staticmethod
    def invalid_credentials_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='invalid_credentials',
            message='Invalid email or password.',
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    @staticmethod
    def authentication_required_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='authentication_required',
            message='Authentication required.',
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    @staticmethod
    def authorization_required_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='insufficient_role',
            message='You do not have access to this resource.',
            status_code=status.HTTP_403_FORBIDDEN,
        )

    def _ensure_runtime_configuration(self) -> None:
        if (
            self.settings.requires_explicit_jwt_secret
            and self.settings.jwt_secret_key == 'replace-me'
        ):
            raise DomainHTTPException(
                code='auth_configuration_error',
                message='JWT secret key is not configured.',
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

    def _ensure_bootstrap_admin(self) -> None:
        if self.user_repository.exists_any():
            return

        bootstrap_email = self.settings.bootstrap_admin_email
        bootstrap_password = self.settings.bootstrap_admin_password
        if not bootstrap_email or not bootstrap_password:
            raise DomainHTTPException(
                code='admin_bootstrap_required',
                message='Admin bootstrap credentials are not configured.',
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        role = (
            self.settings.admin_seed_role
            if self.settings.admin_seed_role in ADMIN_ROLES
            else DEFAULT_ADMIN_ROLE
        )
        self.user_repository.create(
            email=bootstrap_email,
            full_name=self.settings.admin_seed_full_name,
            password_hash=hash_password(bootstrap_password),
            role=role,
        )

    def _create_session_for_user(self, user: AdminUser) -> TokenPair:
        session_id = uuid4().hex
        token_pair = self._generate_token_pair(user=user, session_id=session_id)
        self.session_repository.create(
            session_id=session_id,
            admin_user_id=user.id,
            refresh_token_hash=hash_token_value(token_pair.refresh_token),
            expires_at=token_pair.refresh_expires_at,
        )
        return token_pair

    def _rotate_session_for_user(
        self,
        user: AdminUser,
        session: AdminSession,
    ) -> TokenPair:
        token_pair = self._generate_token_pair(user=user, session_id=session.id)
        self.session_repository.rotate_refresh_token(
            session,
            refresh_token_hash=hash_token_value(token_pair.refresh_token),
            expires_at=token_pair.refresh_expires_at,
        )
        return token_pair

    def _generate_token_pair(
        self,
        *,
        user: AdminUser,
        session_id: str,
    ) -> TokenPair:
        return create_admin_token_pair(
            secret_key=self.settings.jwt_secret_key,
            user_id=user.id,
            role=user.role,
            session_id=session_id,
            access_token_ttl_minutes=self.settings.jwt_access_token_ttl_minutes,
            refresh_token_ttl_days=self.settings.jwt_refresh_token_ttl_days,
        )

    def _get_active_user(self, user_id: str) -> AdminUser:
        user = self.user_repository.get_by_id(user_id)
        if user is None or not user.is_active:
            raise self.authentication_required_exception()
        if user.role not in ADMIN_ROLES:
            raise self.authentication_required_exception()
        return user

    def _get_active_session(self, session_id: str) -> AdminSession:
        session = self.session_repository.get_by_id(session_id)
        if session is None or session.revoked_at is not None:
            raise self.authentication_required_exception()
        if self._normalize_datetime(session.expires_at) <= datetime.now(UTC):
            raise self.authentication_required_exception()
        return session

    def _decode_token(self, token: str, *, expected_type: str) -> TokenPayload:
        try:
            return decode_admin_token(
                token,
                secret_key=self.settings.jwt_secret_key,
                expected_type=expected_type,
            )
        except TokenValidationError as exc:
            raise self.authentication_required_exception() from exc

    def _build_auth_response(
        self,
        user: AdminUser,
        token_pair: TokenPair,
    ) -> AdminAuthResponse:
        return AdminAuthResponse(
            access_token=token_pair.access_token,
            refresh_token=token_pair.refresh_token,
            token_type='bearer',
            expires_in_seconds=token_pair.access_expires_in_seconds,
            refresh_expires_in_seconds=token_pair.refresh_expires_in_seconds,
            user=self._serialize_user(user),
        )

    def _serialize_user(self, user: AdminUser) -> AdminCurrentUserResponse:
        return AdminCurrentUserResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
        )

    def _normalize_datetime(self, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)
