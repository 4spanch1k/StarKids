from collections.abc import Sequence
from dataclasses import dataclass
from ipaddress import IPv4Address, IPv4Network, IPv6Address, IPv6Network, ip_address

from fastapi import Request

from ...core.config.settings import get_settings


@dataclass(frozen=True)
class AuthRequestContext:
    ip_address: str
    user_agent: str | None = None


def get_auth_request_context(request: Request) -> AuthRequestContext:
    client_host = request.client.host if request.client is not None else ''
    ip_address = resolve_client_ip(
        immediate_peer=client_host,
        forwarded_for=request.headers.get('x-forwarded-for'),
        trusted_proxy_networks=get_settings().trusted_proxy_networks,
    )
    return AuthRequestContext(
        ip_address=ip_address,
        user_agent=request.headers.get('user-agent'),
    )


def resolve_client_ip(
    *,
    immediate_peer: str | None,
    forwarded_for: str | None,
    trusted_proxy_networks: Sequence[IPv4Network | IPv6Network],
) -> str:
    """Resolve the client IP only through an explicitly trusted proxy chain."""
    peer_text = (immediate_peer or '').strip()
    peer = _parse_ip(peer_text)
    if peer is None or not _is_trusted(peer, trusted_proxy_networks):
        return peer_text or 'unknown'

    for candidate_text in reversed((forwarded_for or '').split(',')):
        candidate = _parse_ip(candidate_text)
        if candidate is None or _is_trusted(candidate, trusted_proxy_networks):
            continue
        return str(candidate)
    return str(peer)


def _parse_ip(value: str | None) -> IPv4Address | IPv6Address | None:
    candidate = (value or '').strip()
    if not candidate:
        return None
    try:
        return ip_address(candidate)
    except ValueError:
        return None


def _is_trusted(
    address: IPv4Address | IPv6Address,
    networks: Sequence[IPv4Network | IPv6Network],
) -> bool:
    return any(address in network for network in networks)
