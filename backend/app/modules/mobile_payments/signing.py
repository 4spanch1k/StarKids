from __future__ import annotations

from collections.abc import Mapping
import hashlib
import hmac
from urllib.parse import urlparse


def build_freedompay_signature(
    *,
    script_name: str,
    params: Mapping[str, object],
    secret_key: str,
) -> str:
    signing_params = {
        key: value
        for key, value in params.items()
        if key != 'pg_sig' and value is not None
    }
    flat_params = _flatten_params(signing_params)
    signature_parts = [script_name]
    signature_parts.extend(str(flat_params[key]) for key in sorted(flat_params))
    signature_parts.append(secret_key)
    source = ';'.join(signature_parts)
    return hashlib.md5(source.encode('utf-8')).hexdigest()


def verify_freedompay_signature(
    *,
    script_name: str,
    params: Mapping[str, object],
    secret_key: str,
) -> bool:
    received_signature = str(params.get('pg_sig') or '').lower()
    if not received_signature:
        return False
    expected_signature = build_freedompay_signature(
        script_name=script_name,
        params=params,
        secret_key=secret_key,
    )
    return hmac.compare_digest(received_signature, expected_signature)


def signature_script_from_url(url: str | None, fallback: str) -> str:
    if not url:
        return fallback
    parsed_path = urlparse(url).path.rstrip('/')
    script_name = parsed_path.rsplit('/', 1)[-1]
    return script_name or fallback


def _flatten_params(
    params: Mapping[str, object] | list[object],
    parent_name: str = '',
) -> dict[str, str]:
    flat_params: dict[str, str] = {}
    iterable = params.items() if isinstance(params, Mapping) else enumerate(params)
    for index, (key, value) in enumerate(iterable, start=1):
        name = f'{parent_name}{key}{index:03d}'
        if isinstance(value, Mapping) or isinstance(value, list):
            flat_params.update(_flatten_params(value, name))
            continue
        flat_params[name] = str(value)
    return flat_params
