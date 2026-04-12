from __future__ import annotations

from datetime import UTC, datetime
import re
from uuid import uuid4

from fastapi import status

from ...core.config.settings import Settings, get_settings
from ...core.exceptions.http import DomainHTTPException
from ...core.security.passwords import hash_password, verify_password
from ...core.security.tokens import (
    TokenPair,
    TokenValidationError,
    create_mobile_token_pair,
    decode_mobile_token,
    hash_token_value,
)
from ...db.models.mobile_session import MobileSession
from ...db.models.mobile_user import MobileUser
from ...db.repositories.mobile_session_repository import MobileSessionRepository
from ...db.repositories.mobile_user_repository import MobileUserRepository
from .schemas import (
    MobileAuthResponse,
    MobileCurrentUserResponse,
    MobileEmailAuthRequest,
    MobileRefreshRequest,
    OTPRequest,
    OTPRequestResponse,
    OTPVerifyRequest,
)

MOBILE_AUTH_ROLE = 'mobile_user'
PHONE_PATTERN = re.compile(r'^\+7\d{10}$')


class MobileAuthService:
    def __init__(
        self,
        *,
        user_repository: MobileUserRepository | None = None,
        session_repository: MobileSessionRepository | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.user_repository = user_repository or MobileUserRepository()
        self.session_repository = session_repository or MobileSessionRepository()
        self.settings = settings or get_settings()

    def request_otp(self, payload: OTPRequest) -> OTPRequestResponse:
        self._normalize_phone(payload.phone)
        return OTPRequestResponse(
            verification_id=f'otp_{uuid4().hex}',
            expires_in_seconds=300,
        )

    def verify_otp(self, payload: OTPVerifyRequest) -> MobileAuthResponse:
        self._ensure_runtime_configuration()
        phone = self._normalize_phone(payload.phone)
        self._ensure_valid_placeholder_challenge(payload.verification_id)

        user = self._get_or_create_active_user(phone)
        token_pair = self._create_session_for_user(user)
        return self._build_auth_response(user, token_pair)

    def register_with_email(self, payload: MobileEmailAuthRequest) -> MobileAuthResponse:
        self._ensure_runtime_configuration()
        email = self._normalize_email(str(payload.email))

        if self.user_repository.find_by_email(email) is not None:
            raise DomainHTTPException(
                code='email_already_registered',
                message='Email is already registered.',
                status_code=status.HTTP_409_CONFLICT,
                details=[
                    {
                        'field': 'email',
                        'message': 'Этот email уже зарегистрирован.',
                    }
                ],
            )

        user = self.user_repository.create(
            email=email,
            password_hash=hash_password(payload.password),
        )
        token_pair = self._create_session_for_user(user)
        return self._build_auth_response(user, token_pair)

    def login_with_email(self, payload: MobileEmailAuthRequest) -> MobileAuthResponse:
        self._ensure_runtime_configuration()
        email = self._normalize_email(str(payload.email))

        user = self.user_repository.find_by_email(email)
        if (
            user is None
            or not user.is_active
            or user.password_hash is None
            or not verify_password(payload.password, user.password_hash)
        ):
            raise self.invalid_credentials_exception()

        token_pair = self._create_session_for_user(user)
        return self._build_auth_response(user, token_pair)

    def refresh(self, payload: MobileRefreshRequest) -> MobileAuthResponse:
        self._ensure_runtime_configuration()
        token_payload = self._decode_token(
            payload.refresh_token,
            expected_type='refresh',
        )
        user = self._get_active_user(token_payload.subject)
        session = self._get_active_session(token_payload.session_id)

        if session.mobile_user_id != user.id:
            raise self.authentication_required_exception()
        if session.refresh_token_hash != hash_token_value(payload.refresh_token):
            raise self.authentication_required_exception()

        token_pair = self._rotate_session_for_user(user, session)
        return self._build_auth_response(user, token_pair)

    def get_current_user(self, access_token: str) -> MobileCurrentUserResponse:
        user = self.authenticate_access_token(access_token)
        return self._serialize_user(user)

    def logout(self, access_token: str) -> None:
        user, session = self._authenticate_access_token(access_token)
        if session.mobile_user_id != user.id:
            raise self.authentication_required_exception()
        self.session_repository.revoke(session)

    def authenticate_access_token(self, access_token: str) -> MobileUser:
        user, _ = self._authenticate_access_token(access_token)
        return user

    def authenticate_access_context(
        self,
        access_token: str,
    ) -> tuple[MobileUser, MobileSession]:
        return self._authenticate_access_token(access_token)

    @staticmethod
    def authentication_required_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='authentication_required',
            message='Authentication required.',
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    @staticmethod
    def invalid_otp_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='invalid_otp',
            message='Invalid verification code.',
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    @staticmethod
    def invalid_credentials_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='invalid_credentials',
            message='Invalid email or password.',
            status_code=status.HTTP_401_UNAUTHORIZED,
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

    def _normalize_phone(self, phone: str) -> str:
        digits = ''.join(char for char in phone if char.isdigit())

        if digits.startswith('8'):
            digits = f'7{digits[1:]}'
        elif digits and not digits.startswith('7'):
            digits = f'7{digits}'

        normalized = f'+{digits}' if digits else ''
        if not PHONE_PATTERN.fullmatch(normalized):
            raise DomainHTTPException(
                code='validation_error',
                message='Phone number is invalid.',
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                details=[
                    {
                        'field': 'phone',
                        'message': 'Введите корректный номер телефона.',
                    }
                ],
            )
        return normalized

    def _normalize_email(self, email: str) -> str:
        return email.lower().strip()

    def _ensure_valid_placeholder_challenge(self, verification_id: str) -> None:
        if not verification_id.startswith('otp_'):
            raise self.invalid_otp_exception()

    def _get_or_create_active_user(self, phone: str) -> MobileUser:
        user = self.user_repository.find_by_phone(phone)
        if user is None:
            return self.user_repository.create(phone=phone)
        if not user.is_active:
            raise self.authentication_required_exception()
        return user

    def _create_session_for_user(self, user: MobileUser) -> TokenPair:
        session_id = uuid4().hex
        token_pair = self._generate_token_pair(user=user, session_id=session_id)
        self.session_repository.create(
            session_id=session_id,
            mobile_user_id=user.id,
            refresh_token_hash=hash_token_value(token_pair.refresh_token),
            expires_at=token_pair.refresh_expires_at,
        )
        return token_pair

    def _rotate_session_for_user(
        self,
        user: MobileUser,
        session: MobileSession,
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
        user: MobileUser,
        session_id: str,
    ) -> TokenPair:
        return create_mobile_token_pair(
            secret_key=self.settings.jwt_secret_key,
            user_id=user.id,
            role=MOBILE_AUTH_ROLE,
            session_id=session_id,
            access_token_ttl_minutes=self.settings.jwt_access_token_ttl_minutes,
            refresh_token_ttl_days=self.settings.jwt_refresh_token_ttl_days,
        )

    def _get_active_user(self, user_id: str) -> MobileUser:
        user = self.user_repository.get_by_id(user_id)
        if user is None or not user.is_active:
            raise self.authentication_required_exception()
        return user

    def _get_active_session(self, session_id: str) -> MobileSession:
        session = self.session_repository.get_by_id(session_id)
        if session is None or session.revoked_at is not None:
            raise self.authentication_required_exception()
        if self._normalize_datetime(session.expires_at) <= datetime.now(UTC):
            raise self.authentication_required_exception()
        return session

    def _authenticate_access_token(self, access_token: str) -> tuple[MobileUser, MobileSession]:
        self._ensure_runtime_configuration()
        token_payload = self._decode_token(access_token, expected_type='access')
        user = self._get_active_user(token_payload.subject)
        session = self._get_active_session(token_payload.session_id)
        if session.mobile_user_id != user.id:
            raise self.authentication_required_exception()
        return user, session

    def _decode_token(self, token: str, *, expected_type: str):
        try:
            return decode_mobile_token(
                token,
                secret_key=self.settings.jwt_secret_key,
                expected_type=expected_type,
            )
        except TokenValidationError as exc:
            raise self.authentication_required_exception() from exc

    def _build_auth_response(
        self,
        user: MobileUser,
        token_pair: TokenPair,
    ) -> MobileAuthResponse:
        return MobileAuthResponse(
            access_token=token_pair.access_token,
            refresh_token=token_pair.refresh_token,
            token_type='bearer',
            expires_in_seconds=token_pair.access_expires_in_seconds,
            refresh_expires_in_seconds=token_pair.refresh_expires_in_seconds,
            user=self._serialize_user(user),
        )

    def _serialize_user(self, user: MobileUser) -> MobileCurrentUserResponse:
        return MobileCurrentUserResponse(
            id=user.id,
            phone=user.phone,
            email=user.email,
        )

    def _normalize_datetime(self, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)
