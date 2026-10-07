from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from functools import lru_cache
from math import ceil
from threading import Lock
from time import time
from uuid import uuid4

from ..config.settings import Settings
from ..config.settings import get_settings
from ..exceptions.http import DomainHTTPException

try:  # pragma: no cover - import guard is exercised indirectly in tests.
    from redis import Redis
    from redis.exceptions import RedisError
except ImportError:  # pragma: no cover - exercised when dependency is absent.
    Redis = None

    class RedisError(Exception):
        pass


_MEMORY_BUCKETS: dict[str, deque[float]] = {}
_MEMORY_LOCK = Lock()


_REDIS_SLIDING_WINDOW_SCRIPT = """
local key = KEYS[1]
local window_seconds = tonumber(ARGV[1])
local consume = ARGV[2] == '1'
local member = ARGV[3]
local clock = redis.call('TIME')
local now = tonumber(clock[1]) + tonumber(clock[2]) / 1000000
local window_start = now - window_seconds

redis.call('ZREMRANGEBYSCORE', key, '-inf', window_start)
local current_count = redis.call('ZCARD', key)
if consume then
    redis.call('ZADD', key, now, member)
    current_count = current_count + 1
end

local oldest_timestamp = now
if current_count > 0 then
    local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
    oldest_timestamp = tonumber(oldest[2])
end
redis.call('EXPIRE', key, window_seconds)
return {current_count, oldest_timestamp, now}
"""


@dataclass(frozen=True)
class RateLimitStatus:
    allowed: bool
    retry_after_seconds: int
    current_count: int


class RateLimitUnavailableError(DomainHTTPException):
    """Raised when a security-critical distributed limiter cannot decide."""

    def __init__(self) -> None:
        super().__init__(
            code='rate_limit_unavailable',
            message='Rate limiting is temporarily unavailable.',
            status_code=503,
        )


class RateLimitService:
    def __init__(
        self,
        *,
        settings: Settings | None = None,
    ) -> None:
        self._settings = settings or get_settings()
        self._requires_distributed_backend = (
            self._settings.is_staging or self._settings.is_production
        )
        self._redis_client = self._build_redis_client()

    def peek(
        self,
        key: str,
        *,
        limit: int,
        window_seconds: int,
        block_on_limit: bool = False,
    ) -> RateLimitStatus:
        return self._dispatch(
            key=key,
            limit=limit,
            window_seconds=window_seconds,
            consume=False,
            block_on_limit=block_on_limit,
        )

    def consume(
        self,
        key: str,
        *,
        limit: int,
        window_seconds: int,
        block_on_limit: bool = False,
    ) -> RateLimitStatus:
        return self._dispatch(
            key=key,
            limit=limit,
            window_seconds=window_seconds,
            consume=True,
            block_on_limit=block_on_limit,
        )

    def clear(self, key: str) -> None:
        normalized_key = self._normalize_key(key)
        if self._redis_client is not None:
            try:
                self._redis_client.delete(normalized_key)
                return
            except RedisError:
                if self._requires_distributed_backend:
                    return

        if self._requires_distributed_backend:
            return

        with _MEMORY_LOCK:
            _MEMORY_BUCKETS.pop(normalized_key, None)

    def reset(self) -> None:
        with _MEMORY_LOCK:
            _MEMORY_BUCKETS.clear()

    def _dispatch(
        self,
        *,
        key: str,
        limit: int,
        window_seconds: int,
        consume: bool,
        block_on_limit: bool,
    ) -> RateLimitStatus:
        normalized_key = self._normalize_key(key)
        if self._redis_client is not None:
            try:
                return self._redis_window(
                    normalized_key,
                    limit=limit,
                    window_seconds=window_seconds,
                    consume=consume,
                    block_on_limit=block_on_limit,
                )
            except RedisError:
                if self._requires_distributed_backend:
                    raise RateLimitUnavailableError from None

        if self._requires_distributed_backend:
            raise RateLimitUnavailableError

        return self._memory_window(
            normalized_key,
            limit=limit,
            window_seconds=window_seconds,
            consume=consume,
            block_on_limit=block_on_limit,
        )

    def _redis_window(
        self,
        key: str,
        *,
        limit: int,
        window_seconds: int,
        consume: bool,
        block_on_limit: bool,
    ) -> RateLimitStatus:
        assert self._redis_client is not None

        results = self._redis_client.eval(
            _REDIS_SLIDING_WINDOW_SCRIPT,
            1,
            key,
            window_seconds,
            1 if consume else 0,
            uuid4().hex if consume else '',
        )
        current_count = int(results[0])
        oldest_timestamp = float(results[1])
        now = float(results[2])
        retry_after_seconds = self._retry_after_seconds(
            oldest_timestamp=oldest_timestamp,
            now=now,
            window_seconds=window_seconds,
        )

        return RateLimitStatus(
            allowed=self._is_allowed(
                current_count=current_count,
                limit=limit,
                block_on_limit=block_on_limit,
            ),
            retry_after_seconds=retry_after_seconds,
            current_count=current_count,
        )

    def _memory_window(
        self,
        key: str,
        *,
        limit: int,
        window_seconds: int,
        consume: bool,
        block_on_limit: bool,
    ) -> RateLimitStatus:
        now = time()
        with _MEMORY_LOCK:
            bucket = _MEMORY_BUCKETS.setdefault(key, deque())
            while bucket and (now - bucket[0]) >= window_seconds:
                bucket.popleft()

            if consume:
                bucket.append(now)

            current_count = len(bucket)
            retry_after_seconds = self._retry_after_seconds(
                oldest_timestamp=bucket[0] if bucket else now,
                now=now,
                window_seconds=window_seconds,
            )

            if not bucket:
                _MEMORY_BUCKETS.pop(key, None)

        return RateLimitStatus(
            allowed=self._is_allowed(
                current_count=current_count,
                limit=limit,
                block_on_limit=block_on_limit,
            ),
            retry_after_seconds=retry_after_seconds,
            current_count=current_count,
        )

    def _build_redis_client(self) -> Redis | None:
        if Redis is None or not self._settings.redis_url:
            return None
        return Redis.from_url(
            self._settings.redis_url,
            decode_responses=True,
        )

    def _normalize_key(self, key: str) -> str:
        prefix = self._settings.redis_key_prefix.strip(': ')
        suffix = key.strip(': ')
        if not prefix:
            return suffix
        return f'{prefix}:{suffix}'

    @staticmethod
    def _is_allowed(
        *,
        current_count: int,
        limit: int,
        block_on_limit: bool,
    ) -> bool:
        if block_on_limit:
            return current_count < limit
        return current_count <= limit

    @staticmethod
    def _retry_after_seconds(
        *,
        oldest_timestamp: float,
        now: float,
        window_seconds: int,
    ) -> int:
        return max(1, ceil(window_seconds - max(0, now - oldest_timestamp)))


@lru_cache
def get_rate_limit_service() -> RateLimitService:
    return RateLimitService()


def reset_rate_limit_state() -> None:
    get_rate_limit_service().reset()
