from __future__ import annotations

import hashlib
import hmac


class PassQrService:
    prefix = 'bb_pass:v1:'

    def __init__(self, secret: str | None) -> None:
        self._secret = (secret or '').strip()

    @property
    def is_configured(self) -> bool:
        return len(self._secret) >= 32

    def build_payload(self, pass_id: str) -> str:
        if not self.is_configured:
            raise ValueError('Pass QR secret is not configured.')
        signature = hmac.new(self._secret.encode(), pass_id.encode(), hashlib.sha256).hexdigest()
        return f'{self.prefix}{pass_id}:{signature}'

    def verify_payload(self, payload: str) -> str | None:
        if not self.is_configured or not isinstance(payload, str) or not payload.startswith(self.prefix):
            return None
        parts = payload.split(':')
        if len(parts) != 4 or parts[0] != 'bb_pass' or parts[1] != 'v1':
            return None
        pass_id, signature = parts[2], parts[3]
        if not pass_id or len(signature) != hashlib.sha256().digest_size * 2:
            return None
        expected = hmac.new(self._secret.encode(), pass_id.encode(), hashlib.sha256).hexdigest()
        return pass_id if hmac.compare_digest(expected, signature) else None
