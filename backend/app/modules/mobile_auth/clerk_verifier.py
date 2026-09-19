from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import jwt
from jwt import InvalidTokenError, PyJWKClient, PyJWKClientError

from ...core.config.settings import Settings, get_settings


class ClerkConfigurationError(RuntimeError):
    pass


class ClerkTokenVerificationError(ValueError):
    pass


@dataclass(frozen=True)
class VerifiedClerkIdentity:
    clerk_user_id: str
    email: str | None
    email_verified: bool
    first_name: str | None = None
    last_name: str | None = None
    avatar_url: str | None = None


class ClerkSessionVerifier:
    def __init__(self, *, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()

    def verify(self, session_token: str) -> VerifiedClerkIdentity:
        claims = self._decode_session_token(session_token)
        clerk_user_id = claims.get('sub')
        if not isinstance(clerk_user_id, str) or not clerk_user_id.strip():
            raise ClerkTokenVerificationError('Clerk session token is missing subject.')

        user_payload = self._fetch_clerk_user(clerk_user_id.strip())
        return self._identity_from_user_payload(clerk_user_id.strip(), user_payload)

    def _decode_session_token(self, session_token: str) -> dict[str, Any]:
        jwks_url = self._settings.resolved_clerk_jwks_url
        if not jwks_url:
            raise ClerkConfigurationError('Clerk JWKS URL or issuer is not configured.')

        try:
            signing_key = PyJWKClient(jwks_url).get_signing_key_from_jwt(session_token)
            claims = jwt.decode(
                session_token,
                signing_key.key,
                algorithms=['RS256'],
                issuer=self._settings.clerk_issuer,
                options={
                    'require': ['exp', 'iat', 'sub'],
                    'verify_aud': False,
                },
            )
        except (InvalidTokenError, PyJWKClientError) as exc:
            raise ClerkTokenVerificationError('Invalid Clerk session token.') from exc

        authorized_parties = self._settings.clerk_authorized_parties_list
        if authorized_parties:
            authorized_party = claims.get('azp')
            if authorized_party not in authorized_parties:
                raise ClerkTokenVerificationError(
                    'Clerk session token authorized party is not allowed.'
                )

        return claims

    def _fetch_clerk_user(self, clerk_user_id: str) -> dict[str, Any]:
        secret_key = self._settings.clerk_secret_key
        if not secret_key:
            raise ClerkConfigurationError('Clerk secret key is not configured.')

        request = Request(
            f'https://api.clerk.com/v1/users/{clerk_user_id}',
            headers={
                'Authorization': f'Bearer {secret_key}',
                'Accept': 'application/json',
            },
            method='GET',
        )
        try:
            with urlopen(request, timeout=10) as response:
                raw = response.read().decode('utf-8')
        except HTTPError as exc:
            if exc.code in {401, 403}:
                raise ClerkConfigurationError(
                    'Clerk secret key was rejected by Clerk.'
                ) from exc
            raise ClerkTokenVerificationError('Unable to load Clerk user.') from exc
        except URLError as exc:
            raise ClerkTokenVerificationError('Unable to reach Clerk API.') from exc

        try:
            payload = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ClerkTokenVerificationError('Clerk user response was invalid.') from exc

        if not isinstance(payload, dict):
            raise ClerkTokenVerificationError('Clerk user response was invalid.')
        return payload

    def _identity_from_user_payload(
        self,
        clerk_user_id: str,
        payload: dict[str, Any],
    ) -> VerifiedClerkIdentity:
        primary_email_id = payload.get('primary_email_address_id')
        email_payload = self._primary_email_payload(
            payload.get('email_addresses'),
            primary_email_id if isinstance(primary_email_id, str) else None,
        )
        email = None
        email_verified = False
        if email_payload is not None:
            raw_email = email_payload.get('email_address')
            email = raw_email.lower().strip() if isinstance(raw_email, str) else None
            verification = email_payload.get('verification')
            if isinstance(verification, dict):
                email_verified = verification.get('status') == 'verified'

        return VerifiedClerkIdentity(
            clerk_user_id=clerk_user_id,
            email=email,
            email_verified=email_verified,
            first_name=self._optional_string(payload.get('first_name')),
            last_name=self._optional_string(payload.get('last_name')),
            avatar_url=self._optional_string(payload.get('image_url')),
        )

    def _primary_email_payload(
        self,
        email_addresses: object,
        primary_email_id: str | None,
    ) -> dict[str, Any] | None:
        if not isinstance(email_addresses, list):
            return None

        fallback: dict[str, Any] | None = None
        for item in email_addresses:
            if not isinstance(item, dict):
                continue
            if fallback is None:
                fallback = item
            if primary_email_id is not None and item.get('id') == primary_email_id:
                return item
        return fallback

    def _optional_string(self, value: object) -> str | None:
        if not isinstance(value, str):
            return None
        stripped = value.strip()
        return stripped or None
