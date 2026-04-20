from __future__ import annotations

from datetime import UTC, datetime, timedelta
import logging
import random
from uuid import uuid4

from fastapi import status

from ...core.config.settings import Settings, get_settings
from ...core.exceptions.http import DomainHTTPException
from ...core.security.tokens import hash_secret_value, verify_secret_value
from ...db.models.auth_throttle_state import AuthThrottleState
from ...db.repositories.auth_throttle_state_repository import AuthThrottleStateRepository
from .dependencies import AuthRequestContext

logger = logging.getLogger(__name__)

IP_BUCKET = 'ip'
IP_IDENTIFIER_BUCKET = 'ip_identifier'


class AuthProtectionService:
    def __init__(
        self,
        *,
        throttle_repository: AuthThrottleStateRepository,
        settings: Settings | None = None,
    ) -> None:
        self._throttle_repository = throttle_repository
        self._settings = settings or get_settings()

    def ensure_login_allowed(
        self,
        *,
        auth_scope: str,
        context: AuthRequestContext,
        identifier: str | None,
        captcha_id: str | None = None,
        captcha_answer: str | None = None,
    ) -> None:
        now = datetime.now(UTC)
        states = self._existing_states(
            auth_scope=auth_scope,
            ip_address=context.ip_address,
            identifier=identifier,
        )
        dirty = self._normalize_states(states, now)
        locked_state = self._locked_state(states, now)
        if locked_state is not None:
            if dirty:
                self._throttle_repository.save_many(states)
            logger.warning(
                'Auth login blocked by lockout: scope=%s ip=%s identifier=%s',
                auth_scope,
                context.ip_address,
                self._mask_identifier(identifier),
            )
            raise self.locked_exception(locked_state, now=now)

        captcha_state = self._captcha_state(states, now)
        if captcha_state is None:
            if dirty:
                self._throttle_repository.save_many(states)
            return

        if captcha_id and captcha_answer:
            if self._verify_captcha(captcha_state, captcha_id, captcha_answer):
                for state in states:
                    if state.captcha_required:
                        self._clear_captcha(state)
                self._throttle_repository.save_many(states)
                logger.info(
                    'Auth captcha solved: scope=%s ip=%s identifier=%s',
                    auth_scope,
                    context.ip_address,
                    self._mask_identifier(identifier),
                )
                return

            self._issue_captcha(captcha_state, now)
            self._throttle_repository.save_many(states)
            logger.warning(
                'Auth captcha validation failed: scope=%s ip=%s identifier=%s',
                auth_scope,
                context.ip_address,
                self._mask_identifier(identifier),
            )
            raise self.captcha_required_exception(captcha_state, now=now)

        self._ensure_active_captcha(captcha_state, now)
        self._throttle_repository.save_many(states)
        raise self.captcha_required_exception(captcha_state, now=now)

    def register_failed_login(
        self,
        *,
        auth_scope: str,
        context: AuthRequestContext,
        identifier: str | None,
    ) -> None:
        now = datetime.now(UTC)
        states = self._get_or_create_states(
            auth_scope=auth_scope,
            ip_address=context.ip_address,
            identifier=identifier,
        )
        self._normalize_states(states, now)

        for state in states:
            state.failed_attempts += 1
            state.last_failed_at = now

            if state.failed_attempts >= self._settings.auth_login_max_failures:
                state.total_lockouts += 1
                state.failed_attempts = 0
                state.post_lock_failures = 0
                state.lockout_until = now + timedelta(
                    minutes=self._settings.auth_login_lockout_minutes
                )
                self._clear_captcha(state)
                continue

            if state.total_lockouts > 0:
                state.post_lock_failures += 1
                if (
                    state.post_lock_failures
                    >= self._settings.auth_login_captcha_after_failures
                ):
                    state.captcha_required = True
                    self._issue_captcha(state, now)

        self._throttle_repository.save_many(states)

        locked_state = self._locked_state(states, now)
        if locked_state is not None:
            logger.warning(
                'Auth lockout activated: scope=%s ip=%s identifier=%s',
                auth_scope,
                context.ip_address,
                self._mask_identifier(identifier),
            )
            raise self.locked_exception(locked_state, now=now)

        captcha_state = self._captcha_state(states, now)
        if captcha_state is not None:
            logger.warning(
                'Auth captcha required: scope=%s ip=%s identifier=%s',
                auth_scope,
                context.ip_address,
                self._mask_identifier(identifier),
            )
            raise self.captcha_required_exception(captcha_state, now=now)

    def register_successful_login(
        self,
        *,
        auth_scope: str,
        context: AuthRequestContext,
        identifier: str | None,
    ) -> None:
        now = datetime.now(UTC)
        states = self._existing_states(
            auth_scope=auth_scope,
            ip_address=context.ip_address,
            identifier=identifier,
        )
        if not states:
            return

        for state in states:
            self._reset_state(state, now=now)

        self._throttle_repository.save_many(states)

    @staticmethod
    def locked_exception(
        state: AuthThrottleState,
        *,
        now: datetime,
    ) -> DomainHTTPException:
        lockout_until = _normalize_datetime(state.lockout_until)
        retry_after_seconds = max(
            1,
            int((lockout_until - now).total_seconds()),
        )
        return DomainHTTPException(
            code='login_temporarily_locked',
            message='Слишком много неудачных попыток входа. Попробуйте позже.',
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            details=[
                {
                    'field': 'retry_after_seconds',
                    'message': str(retry_after_seconds),
                }
            ],
        )

    @staticmethod
    def captcha_required_exception(
        state: AuthThrottleState,
        *,
        now: datetime,
    ) -> DomainHTTPException:
        captcha_expires_at = _normalize_datetime(state.captcha_expires_at)
        expires_in_seconds = max(
            1,
            int((captcha_expires_at - now).total_seconds()),
        )
        return DomainHTTPException(
            code='captcha_required',
            message='Подтвердите, что вы не робот, чтобы продолжить вход.',
            status_code=status.HTTP_403_FORBIDDEN,
            details=[
                {'field': 'captcha_id', 'message': state.captcha_id or ''},
                {'field': 'captcha_prompt', 'message': state.captcha_prompt or ''},
                {
                    'field': 'captcha_expires_in_seconds',
                    'message': str(expires_in_seconds),
                },
            ],
        )

    def _existing_states(
        self,
        *,
        auth_scope: str,
        ip_address: str,
        identifier: str | None,
    ) -> list[AuthThrottleState]:
        states: list[AuthThrottleState] = []

        ip_state = self._throttle_repository.get_by_bucket(
            auth_scope=auth_scope,
            bucket_type=IP_BUCKET,
            bucket_key=ip_address,
        )
        if ip_state is not None:
            states.append(ip_state)

        if identifier:
            pair_key = self._pair_bucket_key(ip_address, identifier)
            pair_state = self._throttle_repository.get_by_bucket(
                auth_scope=auth_scope,
                bucket_type=IP_IDENTIFIER_BUCKET,
                bucket_key=pair_key,
            )
            if pair_state is not None:
                states.append(pair_state)

        return states

    def _get_or_create_states(
        self,
        *,
        auth_scope: str,
        ip_address: str,
        identifier: str | None,
    ) -> list[AuthThrottleState]:
        states = self._existing_states(
            auth_scope=auth_scope,
            ip_address=ip_address,
            identifier=identifier,
        )
        existing_keys = {(state.bucket_type, state.bucket_key) for state in states}

        if (IP_BUCKET, ip_address) not in existing_keys:
            states.append(
                self._throttle_repository.create(
                    auth_scope=auth_scope,
                    bucket_type=IP_BUCKET,
                    bucket_key=ip_address,
                    ip_address=ip_address,
                    identifier=None,
                )
            )

        if identifier:
            pair_key = self._pair_bucket_key(ip_address, identifier)
            if (IP_IDENTIFIER_BUCKET, pair_key) not in existing_keys:
                states.append(
                    self._throttle_repository.create(
                        auth_scope=auth_scope,
                        bucket_type=IP_IDENTIFIER_BUCKET,
                        bucket_key=pair_key,
                        ip_address=ip_address,
                        identifier=identifier,
                    )
                )

        return states

    def _normalize_states(
        self,
        states: list[AuthThrottleState],
        now: datetime,
    ) -> bool:
        dirty = False
        for state in states:
            if (
                state.lockout_until is not None
                and _normalize_datetime(state.lockout_until) <= now
            ):
                state.lockout_until = None
                state.failed_attempts = 0
                dirty = True

            if state.captcha_required:
                self._ensure_active_captcha(state, now)
                dirty = True
        return dirty

    def _reset_state(
        self,
        state: AuthThrottleState,
        *,
        now: datetime,
    ) -> None:
        state.failed_attempts = 0
        state.post_lock_failures = 0
        state.lockout_until = None
        state.last_success_at = now
        self._clear_captcha(state)

    def _locked_state(
        self,
        states: list[AuthThrottleState],
        now: datetime,
    ) -> AuthThrottleState | None:
        locked = [
            state
            for state in states
            if state.lockout_until is not None
            and _normalize_datetime(state.lockout_until) > now
        ]
        if not locked:
            return None
        return max(locked, key=lambda state: _normalize_datetime(state.lockout_until))

    def _captcha_state(
        self,
        states: list[AuthThrottleState],
        now: datetime,
    ) -> AuthThrottleState | None:
        ordered = sorted(
            states,
            key=lambda state: 0 if state.bucket_type == IP_IDENTIFIER_BUCKET else 1,
        )
        for state in ordered:
            if state.captcha_required:
                self._ensure_active_captcha(state, now)
                return state
        return None

    def _ensure_active_captcha(
        self,
        state: AuthThrottleState,
        now: datetime,
    ) -> None:
        if (
            state.captcha_id is None
            or state.captcha_prompt is None
            or state.captcha_answer_hash is None
            or state.captcha_expires_at is None
            or _normalize_datetime(state.captcha_expires_at) <= now
        ):
            self._issue_captcha(state, now)

    def _issue_captcha(self, state: AuthThrottleState, now: datetime) -> None:
        left = random.randint(1, 9)
        right = random.randint(1, 9)
        captcha_id = uuid4().hex
        answer = str(left + right)
        state.captcha_required = True
        state.captcha_id = captcha_id
        state.captcha_prompt = f'Сколько будет {left} + {right}?'
        state.captcha_answer_hash = hash_secret_value(
            f'{captcha_id}:{answer}',
            secret_key=self._settings.jwt_secret_key,
            purpose='auth-captcha',
        )
        state.captcha_expires_at = now + timedelta(
            minutes=self._settings.auth_captcha_ttl_minutes
        )

    def _verify_captcha(
        self,
        state: AuthThrottleState,
        captcha_id: str,
        captcha_answer: str,
    ) -> bool:
        if (
            state.captcha_id is None
            or state.captcha_answer_hash is None
            or state.captcha_id != captcha_id.strip()
        ):
            return False
        return verify_secret_value(
            f'{captcha_id.strip()}:{captcha_answer.strip()}',
            state.captcha_answer_hash,
            secret_key=self._settings.jwt_secret_key,
            purpose='auth-captcha',
        )

    @staticmethod
    def _clear_captcha(state: AuthThrottleState) -> None:
        state.captcha_required = False
        state.captcha_id = None
        state.captcha_prompt = None
        state.captcha_answer_hash = None
        state.captcha_expires_at = None

    @staticmethod
    def _pair_bucket_key(ip_address: str, identifier: str) -> str:
        return f'{ip_address}|{identifier}'

    @staticmethod
    def _mask_identifier(identifier: str | None) -> str:
        if not identifier:
            return 'unknown'
        if '@' not in identifier:
            return f'{identifier[:3]}***'
        local_part, _, domain = identifier.partition('@')
        return f'{local_part[:2]}***@{domain}'


def _normalize_datetime(value: datetime | None) -> datetime:
    if value is None:
        return datetime.min.replace(tzinfo=UTC)
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
