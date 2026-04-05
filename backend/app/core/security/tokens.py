from dataclasses import dataclass
from uuid import uuid4


@dataclass(frozen=True)
class TokenPair:
    access_token: str
    refresh_token: str


def generate_placeholder_token_pair(prefix: str) -> TokenPair:
    return TokenPair(
        access_token=f'{prefix}_access_{uuid4().hex}',
        refresh_token=f'{prefix}_refresh_{uuid4().hex}',
    )

