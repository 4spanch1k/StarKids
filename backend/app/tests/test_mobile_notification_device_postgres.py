"""PostgreSQL proof for single-owner token rebinding.

Run against a disposable database at Alembic head with
``NOTIFICATION_POSTGRES_URL``. The normal SQLite suite skips this module.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
import os
import threading
import unittest
from uuid import uuid4

from sqlalchemy import delete, select
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.db.models.mobile_notification_device import MobileNotificationDevice
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.db.repositories.mobile_notification_device_repository import (
    MobileNotificationDeviceRepository,
)


@unittest.skipUnless(
    os.getenv('NOTIFICATION_POSTGRES_URL'),
    'set NOTIFICATION_POSTGRES_URL',
)
class MobileNotificationDevicePostgresTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            os.environ['NOTIFICATION_POSTGRES_URL'],
            pool_size=4,
            max_overflow=0,
            pool_pre_ping=True,
        )
        cls.SessionLocal = sessionmaker(
            bind=cls.engine,
            class_=Session,
            expire_on_commit=False,
        )

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def test_concurrent_same_token_leaves_one_owner(self) -> None:
        suffix = uuid4().hex
        token = f'pg-token-{suffix}'
        user_ids = [f'pg-user-{suffix[:10]}-{index}' for index in (1, 2)]
        session_ids = [f'pg-session-{suffix[:8]}-{index}' for index in (1, 2)]

        with self.SessionLocal() as db:
            for user_id, session_id in zip(user_ids, session_ids):
                db.add(MobileUser(id=user_id, phone=f'+77{suffix[:10]}{len(user_id)}'))
                db.flush()
                db.add(
                    MobileSession(
                        id=session_id,
                        mobile_user_id=user_id,
                        refresh_token_hash=f'hash-{session_id}',
                        expires_at=datetime.now(UTC) + timedelta(days=1),
                    )
                )
            db.commit()

        barrier = threading.Barrier(2)

        def register(index: int) -> None:
            with self.SessionLocal() as db:
                barrier.wait()
                MobileNotificationDeviceRepository(db).upsert(
                    mobile_user_id=user_ids[index],
                    mobile_session_id=session_ids[index],
                    platform='android',
                    push_token=token,
                    permission_status='granted',
                    notifications_enabled=True,
                )

        try:
            with ThreadPoolExecutor(max_workers=2) as executor:
                list(executor.map(register, (0, 1)))

            with self.SessionLocal() as db:
                devices = db.scalars(
                    select(MobileNotificationDevice).where(
                        MobileNotificationDevice.push_token == token,
                    )
                ).all()
                self.assertEqual(len(devices), 1)
                self.assertIn(devices[0].mobile_user_id, user_ids)
        finally:
            with self.SessionLocal() as db:
                db.execute(
                    delete(MobileNotificationDevice).where(
                        MobileNotificationDevice.push_token == token,
                    )
                )
                db.execute(delete(MobileSession).where(MobileSession.id.in_(session_ids)))
                db.execute(delete(MobileUser).where(MobileUser.id.in_(user_ids)))
                db.commit()

