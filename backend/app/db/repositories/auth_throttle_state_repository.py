from __future__ import annotations

from collections.abc import Sequence

from sqlalchemy import select

from ..models.auth_throttle_state import AuthThrottleState
from .base import Repository


class AuthThrottleStateRepository(Repository):
    def get_by_bucket(
        self,
        *,
        auth_scope: str,
        bucket_type: str,
        bucket_key: str,
    ) -> AuthThrottleState | None:
        return self.db.scalar(
            select(AuthThrottleState).where(
                AuthThrottleState.auth_scope == auth_scope,
                AuthThrottleState.bucket_type == bucket_type,
                AuthThrottleState.bucket_key == bucket_key,
            )
        )

    def create(
        self,
        *,
        auth_scope: str,
        bucket_type: str,
        bucket_key: str,
        ip_address: str,
        identifier: str | None,
    ) -> AuthThrottleState:
        state = AuthThrottleState(
            auth_scope=auth_scope,
            bucket_type=bucket_type,
            bucket_key=bucket_key,
            ip_address=ip_address,
            identifier=identifier,
        )
        self.db.add(state)
        self.db.flush()
        return state

    def save_many(self, states: Sequence[AuthThrottleState]) -> None:
        for state in states:
            self.db.add(state)
        self.db.commit()
        for state in states:
            self.db.refresh(state)
