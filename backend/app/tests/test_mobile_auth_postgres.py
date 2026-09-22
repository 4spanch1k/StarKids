"""PostgreSQL proof for persisted phone OTP race safety.

Run with ``OTP_POSTGRES_URL`` against a disposable database at Alembic head.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
import os
import threading
import unittest
from unittest.mock import patch
from uuid import uuid4

from sqlalchemy import create_engine, delete, select
from sqlalchemy.orm import Session, sessionmaker

from app.core.config.settings import Settings
from app.core.exceptions.http import DomainHTTPException
from app.db.models import Base
from app.db.models.mobile_otp_challenge import MobileOtpChallenge
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.repositories.auth_throttle_state_repository import AuthThrottleStateRepository
from app.db.repositories.mobile_otp_challenge_repository import MobileOtpChallengeRepository
from app.db.repositories.mobile_session_repository import MobileSessionRepository
from app.db.repositories.mobile_user_repository import MobileUserRepository
from app.modules.auth_security.dependencies import AuthRequestContext
from app.modules.auth_security.service import AuthProtectionService
from app.modules.mobile_auth.schemas import OTPRequest, OTPVerifyRequest
from app.modules.mobile_auth.service import MobileAuthService


class _CountingRewardService:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.calls = 0

    def apply_event(self, **_: object) -> None:
        with self._lock:
            self.calls += 1


@unittest.skipUnless(os.getenv('OTP_POSTGRES_URL'), 'set OTP_POSTGRES_URL')
class MobileAuthPostgresConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            os.environ['OTP_POSTGRES_URL'],
            pool_size=8,
            max_overflow=0,
            pool_pre_ping=True,
        )
        cls.SessionLocal = sessionmaker(
            bind=cls.engine,
            class_=Session,
            expire_on_commit=False,
        )
        Base.metadata.create_all(cls.engine)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def _service(
        self,
        db: Session,
        *,
        loyalty_service: _CountingRewardService | None = None,
    ) -> MobileAuthService:
        settings = Settings(
            app_env='test',
            database_url=os.environ['OTP_POSTGRES_URL'],
            otp_request_limit_per_phone=100,
            otp_request_limit_per_ip=100,
            otp_verify_limit_per_ip_phone=100,
        )
        return MobileAuthService(
            user_repository=MobileUserRepository(db),
            session_repository=MobileSessionRepository(db),
            otp_challenge_repository=MobileOtpChallengeRepository(db),
            auth_protection_service=AuthProtectionService(
                throttle_repository=AuthThrottleStateRepository(db),
                settings=settings,
            ),
            settings=settings,
            loyalty_service=loyalty_service,
        )

    def test_simultaneous_request_leaves_one_active_challenge(self) -> None:
        phone = f'+7707{uuid4().int % 10**7:07d}'
        barrier = threading.Barrier(2)

        def request(index: int) -> str:
            with self.SessionLocal() as db:
                barrier.wait()
                try:
                    response = self._service(db).request_otp(
                        OTPRequest(phone=phone),
                        context=AuthRequestContext(ip_address=f'10.0.0.{index}'),
                    )
                    return response.verification_id
                except DomainHTTPException as error:
                    self.assertEqual(error.status_code, 429)
                    active = db.scalar(
                        select(MobileOtpChallenge.id).where(
                            MobileOtpChallenge.phone == phone,
                            MobileOtpChallenge.consumed_at.is_(None),
                        )
                    )
                    self.assertIsNotNone(active)
                    return active

        with patch('app.modules.mobile_auth.service.secrets.randbelow', return_value=123456):
            with ThreadPoolExecutor(max_workers=2) as executor:
                verification_ids = list(executor.map(request, (1, 2)))

        with self.SessionLocal() as db:
            active = db.scalars(
                select(MobileOtpChallenge).where(
                    MobileOtpChallenge.phone == phone,
                    MobileOtpChallenge.consumed_at.is_(None),
                )
            ).all()
            self.assertEqual(len(active), 1)
            self.assertIn(active[0].id, verification_ids)
            db.execute(delete(MobileOtpChallenge).where(MobileOtpChallenge.phone == phone))
            db.commit()

    def test_two_correct_verifications_consume_once_and_create_one_user(self) -> None:
        phone = f'+7707{uuid4().int % 10**7:07d}'
        with self.SessionLocal() as db:
            service = self._service(db)
            with patch('app.modules.mobile_auth.service.secrets.randbelow', return_value=654321):
                challenge = service.request_otp(
                    OTPRequest(phone=phone),
                    context=AuthRequestContext(ip_address='10.0.1.1'),
                )

        barrier = threading.Barrier(2)
        rewards = _CountingRewardService()

        def verify(index: int) -> bool:
            with self.SessionLocal() as db:
                barrier.wait()
                try:
                    self._service(db, loyalty_service=rewards).verify_otp(
                        OTPVerifyRequest(
                            phone=phone,
                            code='654321',
                            verification_id=challenge.verification_id,
                        ),
                        context=AuthRequestContext(ip_address=f'10.0.1.{index}'),
                    )
                    return True
                except Exception:
                    return False

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(verify, (1, 2)))

        with self.SessionLocal() as db:
            self.assertEqual(sum(results), 1)
            self.assertEqual(db.query(MobileOtpChallenge).filter_by(phone=phone).count(), 1)
            self.assertEqual(
                db.query(MobileOtpChallenge).filter_by(phone=phone, consumed_at=None).count(),
                0,
            )
            self.assertEqual(db.query(MobileUser).filter_by(phone=phone).count(), 1)
            self.assertEqual(rewards.calls, 1)
            db.execute(delete(MobileSession).where(MobileSession.mobile_user_id.in_(select(MobileUser.id).where(MobileUser.phone == phone))))
            db.execute(delete(MobileUser).where(MobileUser.phone == phone))
            db.execute(delete(MobileOtpChallenge).where(MobileOtpChallenge.phone == phone))
            db.commit()
