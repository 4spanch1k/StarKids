"""PostgreSQL proof for retry-safe birthday lead submission.

Run with ``BIRTHDAY_LEAD_POSTGRES_URL`` against a disposable database at
Alembic head. The normal SQLite suite skips this module.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
import os
from threading import Barrier
from uuid import uuid4
import unittest

from sqlalchemy import create_engine, delete, select
from sqlalchemy.orm import Session, sessionmaker

from app.db.models.birthday_package import BirthdayPackage
from app.db.models.birthday_request import BirthdayRequest
from app.db.models.branch import Branch
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_user import MobileUser
from app.modules.leads.schemas import BirthdayLeadCreate
from app.modules.leads.service import LeadService
from app.db.repositories.branch_repository import BranchRepository
from app.db.repositories.birthday_package_repository import BirthdayPackageRepository
from app.db.repositories.lead_repository import LeadRepository
from app.db.repositories.mobile_child_repository import MobileChildRepository


@unittest.skipUnless(
    os.getenv('BIRTHDAY_LEAD_POSTGRES_URL'),
    'BIRTHDAY_LEAD_POSTGRES_URL is not configured',
)
class BirthdayLeadPostgresConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            os.environ['BIRTHDAY_LEAD_POSTGRES_URL'],
            pool_size=4,
            max_overflow=0,
            pool_pre_ping=True,
        )
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def setUp(self) -> None:
        suffix = uuid4().hex
        self.user_id = f'bday-pg-user-{suffix[:12]}'
        self.child_id = f'bday-pg-child-{suffix[:12]}'
        self.branch_id = f'bday-pg-branch-{suffix[:12]}'
        self.package_id = f'bday-pg-package-{suffix[:12]}'
        with self.SessionLocal() as db:
            db.add(MobileUser(id=self.user_id, phone=f'+77{suffix[:10]}', first_name='Айжан'))
            db.flush()
            db.add(MobileChild(id=self.child_id, user_id=self.user_id, name='Али', birth_date=date(2020, 5, 1), gender='male'))
            db.add(Branch(id=self.branch_id, slug=self.branch_id, name='PG branch', city='Almaty', address='Test', short_label='PG', working_hours='10:00 - 22:00', description='Test', phone='+77070000000', whatsapp_phone='+77070000000', hero_image_url=None, gallery_image_urls=[], facilities=[], display_order=1, is_active=True))
            db.flush()
            db.add(BirthdayPackage(id=self.package_id, branch_id=self.branch_id, slug=self.package_id, name='PG package', price_from=55000, price_label='55000', guest_capacity_label='10', description='Test', highlights=[], image_url=None, is_featured=False, is_active=True, display_order=1))
            db.commit()

    def tearDown(self) -> None:
        with self.SessionLocal() as db:
            db.execute(delete(BirthdayRequest).where(BirthdayRequest.mobile_user_id == self.user_id))
            db.execute(delete(BirthdayPackage).where(BirthdayPackage.id == self.package_id))
            db.execute(delete(Branch).where(Branch.id == self.branch_id))
            db.execute(delete(MobileChild).where(MobileChild.id == self.child_id))
            db.execute(delete(MobileUser).where(MobileUser.id == self.user_id))
            db.commit()

    def test_concurrent_same_idempotency_key_creates_one_lead(self) -> None:
        payload = BirthdayLeadCreate(
            name='Айжан', phone='+77071234567', branchId=self.branch_id,
            packageId=self.package_id, childId=self.child_id,
            preferredDate=date.today() + timedelta(days=7), guestCount=12,
            comment='test', idempotencyKey='same-key-for-pg',
        )
        barrier = Barrier(2)

        def submit() -> str:
            with self.SessionLocal() as db:
                barrier.wait()
                service = LeadService(
                    repository=LeadRepository(db),
                    branch_repository=BranchRepository(db),
                    package_repository=BirthdayPackageRepository(db),
                    child_repository=MobileChildRepository(db),
                )
                return service.create_birthday_lead(payload, mobile_user_id=self.user_id).requestId

        with ThreadPoolExecutor(max_workers=2) as executor:
            lead_ids = list(executor.map(lambda _: submit(), range(2)))

        self.assertEqual(lead_ids[0], lead_ids[1])
        with self.SessionLocal() as db:
            rows = db.scalars(select(BirthdayRequest).where(BirthdayRequest.mobile_user_id == self.user_id)).all()
            self.assertEqual(len(rows), 1)
