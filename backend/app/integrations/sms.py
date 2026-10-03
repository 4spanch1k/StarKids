"""SMS delivery boundary for mobile phone authentication.

The repository does not currently select a concrete SMS vendor or expose that
vendor's HTTP contract.  The production adapter therefore fails closed until a
vendor-specific transport is supplied.  Keeping that decision here prevents
OTP business logic from growing provider-specific branches.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Protocol

from ..core.config.settings import Settings

logger = logging.getLogger(__name__)


class SmsProviderError(RuntimeError):
    """Base error raised by an SMS delivery adapter."""


class SmsProviderNotConfigured(SmsProviderError):
    """Raised when no usable delivery adapter/contract is configured."""


class SmsProviderUnavailable(SmsProviderError):
    """Raised when a configured provider cannot accept the message."""


class SmsProvider(Protocol):
    def send_otp(self, *, phone: str, code: str) -> None:
        """Deliver an OTP without returning or logging the code."""


@dataclass(frozen=True)
class DevelopmentSmsProvider:
    """Explicit local-only delivery through the backend development log."""

    expires_in_seconds: int = 300

    def send_otp(self, *, phone: str, code: str) -> None:
        logger.info(
            'Local OTP issued: phone=***%s code=%s expires_in_seconds=%s',
            phone[-2:],
            code,
            self.expires_in_seconds,
        )


@dataclass(frozen=True)
class ProductionSmsProvider:
    """Fail-closed boundary until a concrete vendor contract is selected.

    ``SMS_API_BASE_URL``/``SMS_API_KEY``/``SMS_SENDER`` are intentionally
    provider-neutral configuration slots.  No request is sent using an
    invented payload: the deployment must add a vendor-specific adapter once
    the provider contract is approved.
    """

    settings: Settings

    def send_otp(self, *, phone: str, code: str) -> None:
        del phone, code
        raise SmsProviderNotConfigured(
            'A concrete SMS provider contract is required before production delivery'
        )


def build_sms_provider(settings: Settings) -> SmsProvider:
    """Select local mock delivery or the fail-closed production boundary."""

    if settings.allows_mock_otp:
        return DevelopmentSmsProvider(
            expires_in_seconds=settings.otp_code_ttl_seconds,
        )
    if not settings.sms_is_configured:
        raise SmsProviderNotConfigured('SMS provider configuration is incomplete')
    return ProductionSmsProvider(settings=settings)
