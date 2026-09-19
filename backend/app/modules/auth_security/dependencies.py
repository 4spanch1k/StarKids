from dataclasses import dataclass

from fastapi import Request


@dataclass(frozen=True)
class AuthRequestContext:
    ip_address: str
    user_agent: str | None = None


def get_auth_request_context(request: Request) -> AuthRequestContext:
    forwarded_for = request.headers.get('x-forwarded-for', '')
    forwarded_ip = forwarded_for.split(',')[0].strip() if forwarded_for else ''
    client_host = request.client.host if request.client is not None else ''
    ip_address = forwarded_ip or client_host or 'unknown'
    return AuthRequestContext(
        ip_address=ip_address,
        user_agent=request.headers.get('user-agent'),
    )
