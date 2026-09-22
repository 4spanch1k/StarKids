from __future__ import annotations

import os
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
import unittest
from unittest.mock import Mock
from uuid import uuid4

from redis.exceptions import RedisError

from app.core.config.settings import Settings
from app.core.rate_limit.service import (
    RateLimitService,
    RateLimitUnavailableError,
    reset_rate_limit_state,
)


class RateLimitServiceUnitTests(unittest.TestCase):
    def tearDown(self) -> None:
        reset_rate_limit_state()

    def test_development_without_redis_uses_memory_limiter(self) -> None:
        service = RateLimitService(settings=Settings(app_env='development'))

        first = service.consume('unit:memory', limit=2, window_seconds=60, block_on_limit=True)
        second = service.consume('unit:memory', limit=2, window_seconds=60, block_on_limit=True)

        self.assertTrue(first.allowed)
        self.assertFalse(second.allowed)
        self.assertEqual(second.current_count, 2)

    def test_strict_environment_does_not_fallback_after_redis_error(self) -> None:
        strict = RateLimitService(
            settings=Settings(
                app_env='production',
                redis_url='redis://127.0.0.1:6379/0',
            )
        )
        strict._redis_client = Mock()
        strict._redis_client.eval.side_effect = RedisError('redis is unavailable')

        with self.assertRaises(RateLimitUnavailableError) as raised:
            strict.consume('unit:strict', limit=2, window_seconds=60, block_on_limit=True)
        self.assertEqual(raised.exception.code, 'rate_limit_unavailable')
        self.assertEqual(raised.exception.status_code, 503)
        self.assertNotIn('127.0.0.1', str(raised.exception))

    def test_strict_environment_without_redis_fails_closed(self) -> None:
        strict = RateLimitService(settings=Settings(app_env='staging'))

        with self.assertRaises(RateLimitUnavailableError):
            strict.peek('unit:missing-redis', limit=2, window_seconds=60)

    def test_development_can_fallback_after_redis_error(self) -> None:
        development = RateLimitService(
            settings=Settings(
                app_env='development',
                redis_url='redis://127.0.0.1:6379/0',
            )
        )
        development._redis_client = Mock()
        development._redis_client.eval.side_effect = RedisError('redis is unavailable')

        status = development.consume(
            'unit:development-fallback',
            limit=2,
            window_seconds=60,
            block_on_limit=True,
        )
        self.assertTrue(status.allowed)
        self.assertEqual(status.current_count, 1)


@unittest.skipUnless(
    os.getenv('RATE_LIMIT_REDIS_TEST_URL'),
    'set RATE_LIMIT_REDIS_TEST_URL to run real Redis integration proof',
)
class RealRedisRateLimitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.prefix = f'rate-limit-test:{uuid4().hex}'
        cls.settings = Settings(
            app_env='test',
            redis_url=os.environ['RATE_LIMIT_REDIS_TEST_URL'],
            redis_key_prefix=cls.prefix,
        )
        cls.first = RateLimitService(settings=cls.settings)
        cls.second = RateLimitService(settings=cls.settings)

    def setUp(self) -> None:
        self.key = f'window:{uuid4().hex}'

    def tearDown(self) -> None:
        self.first.clear(self.key)

    def test_independent_instances_share_one_atomic_budget(self) -> None:
        first = self.first.consume(self.key, limit=3, window_seconds=60, block_on_limit=True)
        second = self.second.consume(self.key, limit=3, window_seconds=60, block_on_limit=True)
        denied = self.first.consume(self.key, limit=3, window_seconds=60, block_on_limit=True)
        snapshot = self.second.peek(self.key, limit=3, window_seconds=60, block_on_limit=True)

        self.assertTrue(first.allowed)
        self.assertTrue(second.allowed)
        self.assertFalse(denied.allowed)
        self.assertEqual(snapshot.current_count, 3)
        self.assertGreaterEqual(denied.retry_after_seconds, 1)

    def test_concurrent_consumers_cannot_overshoot_allowed_boundary(self) -> None:
        workers = 20
        barrier = Barrier(workers)

        def consume_once(index: int):
            service = self.first if index % 2 == 0 else self.second
            barrier.wait()
            return service.consume(
                self.key,
                limit=6,
                window_seconds=60,
                block_on_limit=True,
            )

        with ThreadPoolExecutor(max_workers=workers) as executor:
            statuses = list(executor.map(consume_once, range(workers)))

        self.assertLessEqual(sum(status.allowed for status in statuses), 5)
        self.assertEqual(
            self.first.peek(
                self.key,
                limit=6,
                window_seconds=60,
                block_on_limit=True,
            ).current_count,
            workers,
        )

    def test_otp_bucket_families_share_budget_across_instances(self) -> None:
        keys = (
            'otp:request:phone:+77070000000',
            'otp:request:ip:203.0.113.10',
            'otp:verify:203.0.113.10:+77070000000',
        )
        for key in keys:
            with self.subTest(key=key):
                self.first.clear(key)
                first = self.first.consume(
                    key,
                    limit=2,
                    window_seconds=60,
                    block_on_limit=True,
                )
                second = self.second.consume(
                    key,
                    limit=2,
                    window_seconds=60,
                    block_on_limit=True,
                )
                denied = self.first.consume(
                    key,
                    limit=2,
                    window_seconds=60,
                    block_on_limit=True,
                )
                self.assertTrue(first.allowed)
                self.assertFalse(second.allowed)
                self.assertFalse(denied.allowed)
                self.assertEqual(denied.current_count, 3)
