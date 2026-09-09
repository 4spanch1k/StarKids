from __future__ import annotations

import hashlib
import hmac


class TicketQrService:
    """Builds and verifies the stable, versioned payload used by ticket QR codes."""

    prefix = 'bb_ticket:v1:'

    def __init__(self, secret: str | None) -> None:
        normalized = (secret or '').strip()
        if normalized and len(normalized) < 32:
            raise ValueError('Ticket QR secret must contain at least 32 characters.')
        self._secret = normalized.encode('utf-8') or None

    @property
    def is_configured(self) -> bool:
        return self._secret is not None

    def build_payload(self, ticket_id: str) -> str:
        if self._secret is None:
            raise RuntimeError('Ticket QR secret is not configured.')
        if not ticket_id or ':' in ticket_id:
            raise ValueError('Ticket id is not valid for a QR payload.')
        canonical = f'{self.prefix}{ticket_id}'
        signature = hmac.new(
            self._secret,
            canonical.encode('utf-8'),
            hashlib.sha256,
        ).hexdigest()
        return f'{canonical}:{signature}'

    def verify_payload(self, payload: str) -> str | None:
        if self._secret is None:
            return None
        if not isinstance(payload, str) or not payload.startswith(self.prefix):
            return None
        parts = payload.split(':')
        if len(parts) != 4 or parts[0] != 'bb_ticket' or parts[1] != 'v1':
            return None
        ticket_id, signature = parts[2], parts[3]
        if not ticket_id or ':' in ticket_id or len(signature) != 64:
            return None
        expected = hmac.new(
            self._secret,
            f'{self.prefix}{ticket_id}'.encode('utf-8'),
            hashlib.sha256,
        ).hexdigest()
        return ticket_id if hmac.compare_digest(signature, expected) else None
