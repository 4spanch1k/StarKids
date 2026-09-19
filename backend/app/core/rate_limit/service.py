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

try:  # pragma: no cover - import guard is exercised indirectly in tests.
    from redis import Redis
    from redis.exceptions import RedisError
except ImportError:  # pragma: no cover - exercised when dependency is absent.
    Redis = None

    class RedisError(Exception):
        pass


_MEMORY_BUCKETS: dict[str, deque[float]] = {}
_MEMORY_LOCK = Lock()


@dataclass(frozen=True)
class RateLimitStatus:
    allowed: bool
    retry_after_seconds: int
    current_count: int


class RateLimitService:
    def __init__(
        self,
        *,
        settings: Settings | None = None,
    ) -> None:
        self._settings = settings or get_settings()
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
            except RedisError:
                pass

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
                pass

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

        now = time()
        window_start = now - window_seconds
        pipeline = self._redis_client.pipeline(transaction=False)
        pipeline.zremrangebyscore(key, 0, window_start)
        pipeline.zcard(key)
        if consume:
            pipeline.zadd(key, {f'{now}:{uuid4().hex}': now})
        pipeline.zrange(key, 0, 0, withscores=True)
        pipeline.expire(key, window_seconds)
        results = pipeline.execute()

        current_count = int(results[1]) + (1 if consume else 0)
        oldest_entry = results[3 if consume else 2]
        retry_after_seconds = self._retry_after_seconds(
            oldest_timestamp=float(oldest_entry[0][1]) if oldest_entry else now,
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
