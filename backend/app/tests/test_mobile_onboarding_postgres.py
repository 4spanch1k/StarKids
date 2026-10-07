from __future__ import annotations

import os
import unittest
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_user import MobileUser
from app.modules.mobile_onboarding.schemas import (
    OnboardingChildInput,
    OnboardingCompleteRequest,
    OnboardingGender,
)
from app.modules.mobile_onboarding.service import MobileOnboardingService


@unittest.skipUnless(
    os.getenv('ONBOARDING_POSTGRES_URL'),
    'ONBOARDING_POSTGRES_URL is not configured',
)
class MobileOnboardingPostgresConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            os.environ['ONBOARDING_POSTGRES_URL'],
            pool_size=4,
            max_overflow=0,
            pool_pre_ping=True,
        )
        cls.SessionLocal = sessionmaker(
            bind=cls.engine,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
            class_=Session,
        )

    def setUp(self) -> None:
        self.user_id = uuid4().hex
        with self.SessionLocal() as session:
            session.add(
                MobileUser(
                    id=self.user_id,
                    phone=f'7{self.user_id[:10]}',
                )
            )
            session.commit()

    def tearDown(self) -> None:
        with self.SessionLocal() as session:
            session.query(MobileChild).filter(
                MobileChild.user_id == self.user_id,
            ).delete()
            session.query(MobileUser).filter(
                MobileUser.id == self.user_id,
            ).delete()
            session.commit()

    def test_concurrent_completion_creates_one_child_set(self) -> None:
        payload = OnboardingCompleteRequest(
            firstName='Айжан',
            children=[
                OnboardingChildInput(
                    name='Али',
                    birthDate='2020-05-01',
                    gender=OnboardingGender.male,
                ),
                OnboardingChildInput(
                    name='Али',
                    birthDate='2020-05-01',
                    gender=OnboardingGender.male,
                ),
            ],
            privacyConsentAccepted=True,
            privacyConsentVersion='v1-pending-legal',
        )
        barrier = Barrier(2)

        def complete() -> bool:
            with self.SessionLocal() as session:
                user = session.get(MobileUser, self.user_id)
                assert user is not None
                barrier.wait()
                result = MobileOnboardingService(session=session).complete(
                    user=user,
                    payload=payload,
                )
                return result.onboardingCompleted

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: complete(), range(2)))

        with self.SessionLocal() as session:
            children_count = session.query(MobileChild).filter(
                MobileChild.user_id == self.user_id,
            ).count()

        self.assertEqual(results, [True, True])
        self.assertEqual(children_count, 2)
