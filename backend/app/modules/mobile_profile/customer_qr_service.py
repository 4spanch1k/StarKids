from __future__ import annotations

from datetime import UTC, datetime, timedelta
import hashlib
import hmac
import time


class CustomerQrService:
    """Build and verify short-lived, account-identification QR payloads."""

    prefix = 'bb_customer:v1:'
    ttl = timedelta(minutes=10)

    def __init__(self, secret: str | None) -> None:
        normalized = (secret or '').strip()
        if normalized and len(normalized) < 32:
            raise ValueError('Customer QR secret must contain at least 32 characters.')
        self._secret = normalized.encode('utf-8') or None

    @property
    def is_configured(self) -> bool:
        return self._secret is not None

    def build_payload(self, user_id: str) -> tuple[str, datetime]:
        if self._secret is None:
            raise RuntimeError('Customer QR secret is not configured.')
        if not user_id or ':' in user_id:
            raise ValueError('Customer id is not valid for a QR payload.')

        expires_epoch = int(time.time() + self.ttl.total_seconds())
        canonical = f'{self.prefix}{user_id}:{expires_epoch}'
        signature = hmac.new(
            self._secret,
            canonical.encode('utf-8'),
            hashlib.sha256,
        ).hexdigest()
        expires_at = datetime.fromtimestamp(expires_epoch, tz=UTC)
        return f'{canonical}:{signature}', expires_at

    def verify_payload(self, payload: str) -> str | None:
        if self._secret is None:
            return None
        if not isinstance(payload, str) or not payload.startswith(self.prefix):
            return None

        parts = payload.split(':')
        if len(parts) != 5 or parts[0] != 'bb_customer' or parts[1] != 'v1':
            return None
        user_id, expires_raw, signature = parts[2], parts[3], parts[4]
        if not user_id or ':' in user_id or len(signature) != 64:
            return None
        try:
            expires_epoch = int(expires_raw)
        except (TypeError, ValueError):
            return None
        if expires_epoch <= int(time.time()):
            return None

        canonical = f'{self.prefix}{user_id}:{expires_epoch}'
        expected = hmac.new(
            self._secret,
            canonical.encode('utf-8'),
            hashlib.sha256,
        ).hexdigest()
        return user_id if hmac.compare_digest(signature, expected) else None
