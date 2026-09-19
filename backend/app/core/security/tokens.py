from __future__ import annotations

from uuid import uuid4
from base64 import urlsafe_b64decode, urlsafe_b64encode
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
import hashlib
import hmac
import json

JWT_ALGORITHM = 'HS256'
ADMIN_JWT_ISSUER = 'star-kids-admin'
MOBILE_JWT_ISSUER = 'star-kids-mobile'
TOKEN_HASH_SCHEME_HMAC_SHA256 = 'hmac-sha256'
TOKEN_HASH_SCHEME_SHA256 = 'sha256'


@dataclass(frozen=True)
class TokenPair:
    access_token: str
    refresh_token: str
    access_expires_in_seconds: int
    refresh_expires_in_seconds: int
    access_expires_at: datetime
    refresh_expires_at: datetime


@dataclass(frozen=True)
class TokenPayload:
    subject: str
    role: str
    token_type: str
    session_id: str
    token_id: str
    issued_at: datetime
    expires_at: datetime


class TokenValidationError(ValueError):
    pass


def create_admin_token_pair(
    *,
    secret_key: str,
    user_id: str,
    role: str,
    session_id: str,
    access_token_ttl_minutes: int,
    refresh_token_ttl_days: int,
    now: datetime | None = None,
) -> TokenPair:
    return _create_token_pair(
        secret_key=secret_key,
        user_id=user_id,
        role=role,
        session_id=session_id,
        access_token_ttl_minutes=access_token_ttl_minutes,
        refresh_token_ttl_days=refresh_token_ttl_days,
        issuer=ADMIN_JWT_ISSUER,
        now=now,
    )


def create_mobile_token_pair(
    *,
    secret_key: str,
    user_id: str,
    role: str,
    session_id: str,
    access_token_ttl_minutes: int,
    refresh_token_ttl_days: int,
    now: datetime | None = None,
) -> TokenPair:
    return _create_token_pair(
        secret_key=secret_key,
        user_id=user_id,
        role=role,
        session_id=session_id,
        access_token_ttl_minutes=access_token_ttl_minutes,
        refresh_token_ttl_days=refresh_token_ttl_days,
        issuer=MOBILE_JWT_ISSUER,
        now=now,
    )


def _create_token_pair(
    *,
    secret_key: str,
    user_id: str,
    role: str,
    session_id: str,
    access_token_ttl_minutes: int,
    refresh_token_ttl_days: int,
    issuer: str,
    now: datetime | None = None,
) -> TokenPair:
    issued_at = now or datetime.now(UTC)
    access_expires_at = issued_at + timedelta(minutes=access_token_ttl_minutes)
    refresh_expires_at = issued_at + timedelta(days=refresh_token_ttl_days)

    access_token = _encode_jwt(
        {
            'iss': issuer,
            'sub': user_id,
            'role': role,
            'type': 'access',
            'sid': session_id,
            'jti': uuid4().hex,
            'iat': _timestamp(issued_at),
            'exp': _timestamp(access_expires_at),
        },
        secret_key,
    )
    refresh_token = _encode_jwt(
        {
            'iss': issuer,
            'sub': user_id,
            'role': role,
            'type': 'refresh',
            'sid': session_id,
            'jti': uuid4().hex,
            'iat': _timestamp(issued_at),
            'exp': _timestamp(refresh_expires_at),
        },
        secret_key,
    )
    return TokenPair(
        access_token=access_token,
        refresh_token=refresh_token,
        access_expires_in_seconds=int(
            timedelta(minutes=access_token_ttl_minutes).total_seconds()
        ),
        refresh_expires_in_seconds=int(
            timedelta(days=refresh_token_ttl_days).total_seconds()
        ),
        access_expires_at=access_expires_at,
        refresh_expires_at=refresh_expires_at,
    )


def decode_admin_token(
    token: str,
    *,
    secret_key: str,
    expected_type: str | None = None,
    now: datetime | None = None,
) -> TokenPayload:
    return _decode_token(
        token,
        secret_key=secret_key,
        expected_type=expected_type,
        issuer=ADMIN_JWT_ISSUER,
        now=now,
    )


def decode_mobile_token(
    token: str,
    *,
    secret_key: str,
    expected_type: str | None = None,
    now: datetime | None = None,
) -> TokenPayload:
    return _decode_token(
        token,
        secret_key=secret_key,
        expected_type=expected_type,
        issuer=MOBILE_JWT_ISSUER,
        now=now,
    )


def _decode_token(
    token: str,
    *,
    secret_key: str,
    expected_type: str | None,
    issuer: str,
    now: datetime | None,
) -> TokenPayload:
    payload = _decode_jwt(token, secret_key)

    token_type = payload.get('type')
    subject = payload.get('sub')
    role = payload.get('role')
    session_id = payload.get('sid')
    token_id = payload.get('jti')
    issued_at = payload.get('iat')
    expires_at = payload.get('exp')

    if payload.get('iss') != issuer:
        raise TokenValidationError('Invalid token issuer.')
    if not all(
        isinstance(value, str) and value
        for value in (token_type, subject, role, session_id, token_id)
    ):
        raise TokenValidationError('Token payload is incomplete.')
    if not isinstance(issued_at, int) or not isinstance(expires_at, int):
        raise TokenValidationError('Token timestamps are invalid.')
    if expected_type and token_type != expected_type:
        raise TokenValidationError('Unexpected token type.')
    if expires_at <= _timestamp(now or datetime.now(UTC)):
        raise TokenValidationError('Token expired.')

    return TokenPayload(
        subject=subject,
        role=role,
        token_type=token_type,
        session_id=session_id,
        token_id=token_id,
        issued_at=datetime.fromtimestamp(issued_at, tz=UTC),
        expires_at=datetime.fromtimestamp(expires_at, tz=UTC),
    )


def hash_secret_value(
    value: str,
    *,
    secret_key: str,
    purpose: str,
) -> str:
    digest = hmac.new(
        secret_key.encode('utf-8'),
        f'{purpose}:{value}'.encode('utf-8'),
        hashlib.sha256,
    ).hexdigest()
    return f'{TOKEN_HASH_SCHEME_HMAC_SHA256}${digest}'


def verify_secret_value(
    value: str,
    stored_hash: str,
    *,
    secret_key: str,
    purpose: str,
) -> bool:
    expected_hash = hash_secret_value(
        value,
        secret_key=secret_key,
        purpose=purpose,
    )
    return hmac.compare_digest(expected_hash, stored_hash)


def hash_token_value(
    token: str,
    *,
    secret_key: str,
) -> str:
    return hash_secret_value(
        token,
        secret_key=secret_key,
        purpose='refresh-token',
    )


def verify_token_value(
    token: str,
    stored_hash: str,
    *,
    secret_key: str,
) -> bool:
    if stored_hash.startswith(f'{TOKEN_HASH_SCHEME_HMAC_SHA256}$'):
        return verify_secret_value(
            token,
            stored_hash,
            secret_key=secret_key,
            purpose='refresh-token',
        )

    legacy_digest = hashlib.sha256(token.encode('utf-8')).hexdigest()
    legacy_stored_hash = stored_hash
    if stored_hash.startswith(f'{TOKEN_HASH_SCHEME_SHA256}$'):
        legacy_stored_hash = stored_hash.split('$', maxsplit=1)[1]
    return hmac.compare_digest(legacy_digest, legacy_stored_hash)


def generate_placeholder_token_pair(prefix: str) -> TokenPair:
    issued_at = datetime.now(UTC)
    return TokenPair(
        access_token=f'{prefix}_access_{uuid4().hex}',
        refresh_token=f'{prefix}_refresh_{uuid4().hex}',
        access_expires_in_seconds=0,
        refresh_expires_in_seconds=0,
        access_expires_at=issued_at,
        refresh_expires_at=issued_at,
    )


def _encode_jwt(payload: dict[str, object], secret_key: str) -> str:
    header_segment = _base64url_encode(
        json.dumps(
            {'alg': JWT_ALGORITHM, 'typ': 'JWT'},
            separators=(',', ':'),
            sort_keys=True,
        ).encode('utf-8')
    )
    payload_segment = _base64url_encode(
        json.dumps(payload, separators=(',', ':'), sort_keys=True).encode('utf-8')
    )
    signing_input = f'{header_segment}.{payload_segment}'.encode('ascii')
    signature_segment = _base64url_encode(
        hmac.new(
            secret_key.encode('utf-8'),
            signing_input,
            hashlib.sha256,
        ).digest()
    )
    return f'{header_segment}.{payload_segment}.{signature_segment}'


def _decode_jwt(token: str, secret_key: str) -> dict[str, object]:
    try:
        header_segment, payload_segment, signature_segment = token.split('.')
    except ValueError as exc:
        raise TokenValidationError('Invalid token format.') from exc

    signing_input = f'{header_segment}.{payload_segment}'.encode('ascii')
    expected_signature = _base64url_encode(
        hmac.new(
            secret_key.encode('utf-8'),
            signing_input,
            hashlib.sha256,
        ).digest()
    )
    if not hmac.compare_digest(expected_signature, signature_segment):
        raise TokenValidationError('Invalid token signature.')

    try:
        header = json.loads(_base64url_decode(header_segment))
        payload = json.loads(_base64url_decode(payload_segment))
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        raise TokenValidationError('Invalid token encoding.') from exc

    if not isinstance(header, dict) or header.get('alg') != JWT_ALGORITHM:
        raise TokenValidationError('Unsupported token algorithm.')
    if not isinstance(payload, dict):
        raise TokenValidationError('Invalid token payload.')
    return payload


def _base64url_encode(value: bytes) -> str:
    return urlsafe_b64encode(value).decode('ascii').rstrip('=')


def _base64url_decode(value: str) -> bytes:
    padding = '=' * (-len(value) % 4)
    return urlsafe_b64decode(f'{value}{padding}'.encode('ascii'))


def _timestamp(value: datetime) -> int:
    return int(value.timestamp())
