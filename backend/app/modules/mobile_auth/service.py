from __future__ import annotations

from datetime import UTC, datetime
import logging
import re
from uuid import uuid4

from fastapi import status
from sqlalchemy.exc import IntegrityError

from ...core.config.settings import Settings, get_settings
from ...core.config.validation import (
    ProductionConfigurationError,
    validate_runtime_configuration,
)
from ...core.exceptions.http import DomainHTTPException
from ...core.security.passwords import (
    PasswordPolicyError,
    hash_password,
    run_dummy_password_verification,
    validate_password_strength,
    verify_and_upgrade_password,
)
from ...core.security.tokens import (
    TokenPair,
    TokenValidationError,
    create_mobile_token_pair,
    decode_mobile_token,
    hash_token_value,
    verify_token_value,
)
from ...db.models.mobile_session import MobileSession
from ...db.models.mobile_user import MobileUser
from ...db.repositories.mobile_session_repository import MobileSessionRepository
from ...db.repositories.mobile_user_repository import MobileUserRepository
from ..auth_security.dependencies import AuthRequestContext
from ..auth_security.service import AuthProtectionService
from .clerk_verifier import (
    ClerkConfigurationError,
    ClerkSessionVerifier,
    ClerkTokenVerificationError,
    VerifiedClerkIdentity,
)
from .schemas import (
    MobileClerkExchangeRequest,
    MobileAuthResponse,
    MobileCurrentUserResponse,
    MobileEmailLoginRequest,
    MobileEmailRegistrationRequest,
    MobileRefreshRequest,
    OTPRequest,
    OTPRequestResponse,
    OTPVerifyRequest,
)

MOBILE_AUTH_ROLE = 'mobile_user'
PHONE_PATTERN = re.compile(r'^\+7\d{10}$')
logger = logging.getLogger(__name__)


class MobileAuthService:
    def __init__(
        self,
        *,
        user_repository: MobileUserRepository | None = None,
        session_repository: MobileSessionRepository | None = None,
        auth_protection_service: AuthProtectionService | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.user_repository = user_repository or MobileUserRepository()
        self.session_repository = session_repository or MobileSessionRepository()
        self.settings = settings or get_settings()
        self.auth_protection_service = auth_protection_service

    def request_otp(self, payload: OTPRequest) -> OTPRequestResponse:
        self._normalize_phone(payload.phone)
        self._ensure_otp_available()
        return OTPRequestResponse(
            verification_id=f'otp_{uuid4().hex}',
            expires_in_seconds=300,
        )

    def verify_otp(self, payload: OTPVerifyRequest) -> MobileAuthResponse:
        self._ensure_runtime_configuration()
        self._ensure_otp_available()
        phone = self._normalize_phone(payload.phone)
        self._ensure_valid_placeholder_challenge(payload.verification_id)

        user = self._get_or_create_active_user(phone)
        self.user_repository.record_successful_login(user)
        token_pair = self._create_session_for_user(user)
        return self._build_auth_response(user, token_pair)

    def register_with_email(
        self,
        payload: MobileEmailRegistrationRequest,
    ) -> MobileAuthResponse:
        self._ensure_runtime_configuration()
        email = self._normalize_email(str(payload.email))
        self._validate_password_strength(payload.password)

        if self.user_repository.find_by_email(email) is not None:
            logger.info('Mobile registration rejected for duplicate email=%s', email)
            raise self.account_already_exists_exception()

        try:
            user = self.user_repository.create(
                email=email,
                password_hash=hash_password(payload.password),
            )
        except IntegrityError as exc:
            self.user_repository.db.rollback()
            logger.warning(
                'Mobile registration hit email uniqueness conflict for email=%s',
                email,
            )
            raise self.account_already_exists_exception() from exc

        self.user_repository.record_successful_login(user)
        token_pair = self._create_session_for_user(user)
        return self._build_auth_response(user, token_pair)

    def login_with_email(
        self,
        payload: MobileEmailLoginRequest,
        *,
        context: AuthRequestContext | None = None,
    ) -> MobileAuthResponse:
        self._ensure_runtime_configuration()
        context = context or AuthRequestContext(ip_address='unknown')
        email = self._normalize_email(str(payload.email))
        self._auth_protection_service.ensure_login_allowed(
            auth_scope='mobile_email',
            context=context,
            identifier=email,
            captcha_id=payload.captcha_id,
            captcha_answer=payload.captcha_answer,
        )

        user = self.user_repository.find_by_email(email)
        if user is None or not user.is_active or user.password_hash is None:
            run_dummy_password_verification(payload.password)
            logger.warning(
                'Mobile login failed: ip=%s identifier=%s reason=user_not_found',
                context.ip_address,
                email,
            )
            self._auth_protection_service.register_failed_login(
                auth_scope='mobile_email',
                context=context,
                identifier=email,
            )
            raise self.invalid_credentials_exception()

        password_verification = verify_and_upgrade_password(
            payload.password,
            user.password_hash,
        )
        if not password_verification.is_valid:
            logger.warning(
                'Mobile login failed: ip=%s identifier=%s reason=invalid_password',
                context.ip_address,
                email,
            )
            self._auth_protection_service.register_failed_login(
                auth_scope='mobile_email',
                context=context,
                identifier=email,
            )
            raise self.invalid_credentials_exception()

        if password_verification.upgraded_hash is not None:
            self.user_repository.update_password_hash(
                user,
                password_hash=password_verification.upgraded_hash,
            )
            user = self.user_repository.get_by_id(user.id) or user

        self.user_repository.record_successful_login(user)
        self._auth_protection_service.register_successful_login(
            auth_scope='mobile_email',
            context=context,
            identifier=email,
        )
        token_pair = self._create_session_for_user(user)
        logger.info(
            'Mobile login succeeded: ip=%s identifier=%s',
            context.ip_address,
            email,
        )
        return self._build_auth_response(user, token_pair)

    def exchange_clerk_session(
        self,
        payload: MobileClerkExchangeRequest,
        *,
        verifier: ClerkSessionVerifier,
    ) -> MobileAuthResponse:
        self._ensure_runtime_configuration()
        identity = self._verify_clerk_session(payload.session_token, verifier=verifier)
        user = self._get_or_create_user_from_clerk_identity(identity)
        self.user_repository.record_successful_login(user)
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
        if not verify_token_value(
            payload.refresh_token,
            session.refresh_token_hash,
            secret_key=self.settings.jwt_secret_key,
        ):
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
            message='Неверный логин или пароль.',
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    @staticmethod
    def account_already_exists_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='account_already_exists',
            message='Аккаунт с такими данными уже существует.',
            status_code=status.HTTP_409_CONFLICT,
            details=[
                {
                    'field': 'email',
                    'message': 'Попробуйте войти или восстановить доступ.',
                }
            ],
        )

    @staticmethod
    def account_already_linked_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='account_already_linked',
            message='Этот email уже связан с другим Google-аккаунтом.',
            status_code=status.HTTP_409_CONFLICT,
            details=[
                {
                    'field': 'email',
                    'message': 'Войдите другим способом или обратитесь в Boom Bala.',
                }
            ],
        )

    @staticmethod
    def unverified_clerk_email_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='clerk_email_not_verified',
            message='Email Google-аккаунта не подтвержден.',
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            details=[
                {
                    'field': 'email',
                    'message': 'Подтвердите email в Google/Clerk и попробуйте снова.',
                }
            ],
        )

    @staticmethod
    def invalid_clerk_session_exception() -> DomainHTTPException:
        return DomainHTTPException(
            code='invalid_clerk_session',
            message='Clerk session token is invalid.',
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    @staticmethod
    def clerk_configuration_exception(message: str) -> DomainHTTPException:
        return DomainHTTPException(
            code='clerk_configuration_error',
            message=message,
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    def _ensure_runtime_configuration(self) -> None:
        try:
            validate_runtime_configuration(self.settings)
        except ProductionConfigurationError as exc:
            raise DomainHTTPException(
                code='auth_configuration_error',
                message='Authentication configuration is not safe for this environment.',
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            ) from exc

    def _ensure_otp_available(self) -> None:
        if self.settings.is_production:
            raise DomainHTTPException(
                code='otp_not_configured',
                message='OTP authentication is not configured for production.',
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

    def _verify_clerk_session(
        self,
        session_token: str,
        *,
        verifier: ClerkSessionVerifier,
    ) -> VerifiedClerkIdentity:
        try:
            return verifier.verify(session_token)
        except ClerkConfigurationError as exc:
            logger.error('Clerk mobile auth configuration error: %s', exc)
            raise self.clerk_configuration_exception(str(exc)) from exc
        except ClerkTokenVerificationError as exc:
            logger.warning('Clerk mobile auth exchange failed: %s', exc)
            raise self.invalid_clerk_session_exception() from exc

    def _normalize_email(self, email: str) -> str:
        return email.lower().strip()

    def _validate_password_strength(self, password: str) -> None:
        try:
            validate_password_strength(
                password,
                min_length=self.settings.auth_password_min_length,
            )
        except PasswordPolicyError as exc:
            raise DomainHTTPException(
                code='weak_password',
                message='Пароль не соответствует требованиям безопасности.',
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                details=[{'field': 'password', 'message': str(exc)}],
            ) from exc

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

    def _get_or_create_user_from_clerk_identity(
        self,
        identity: VerifiedClerkIdentity,
    ) -> MobileUser:
        if not identity.email or not identity.email_verified:
            raise self.unverified_clerk_email_exception()

        user = self.user_repository.find_by_clerk_user_id(identity.clerk_user_id)
        if user is not None:
            if not user.is_active:
                raise self.authentication_required_exception()
            return user

        email = self._normalize_email(identity.email)
        existing_user = self.user_repository.find_by_email(email)
        if existing_user is not None:
            if not existing_user.is_active:
                raise self.authentication_required_exception()
            if existing_user.clerk_user_id == identity.clerk_user_id:
                return existing_user
            if existing_user.clerk_user_id is not None:
                raise self.account_already_linked_exception()
            try:
                return self.user_repository.update(
                    existing_user,
                    clerk_user_id=identity.clerk_user_id,
                )
            except IntegrityError as exc:
                self.user_repository.db.rollback()
                raise self.account_already_linked_exception() from exc

        try:
            return self.user_repository.create(
                email=email,
                clerk_user_id=identity.clerk_user_id,
                first_name=identity.first_name,
                last_name=identity.last_name,
                avatar_url=identity.avatar_url,
            )
        except IntegrityError as exc:
            self.user_repository.db.rollback()
            logger.warning(
                'Clerk mobile auth exchange hit uniqueness conflict: clerk_user_id=%s email=%s',
                identity.clerk_user_id,
                email,
            )
            raise self.account_already_linked_exception() from exc

    def _create_session_for_user(self, user: MobileUser) -> TokenPair:
        session_id = uuid4().hex
        token_pair = self._generate_token_pair(user=user, session_id=session_id)
        self.session_repository.create(
            session_id=session_id,
            mobile_user_id=user.id,
            refresh_token_hash=hash_token_value(
                token_pair.refresh_token,
                secret_key=self.settings.jwt_secret_key,
            ),
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
            refresh_token_hash=hash_token_value(
                token_pair.refresh_token,
                secret_key=self.settings.jwt_secret_key,
            ),
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

    @property
    def _auth_protection_service(self) -> AuthProtectionService:
        if self.auth_protection_service is None:
            raise RuntimeError('Auth protection service is not configured.')
        return self.auth_protection_service
