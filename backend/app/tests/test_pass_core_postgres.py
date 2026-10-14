"""Required PostgreSQL proof for same-day pass redemption atomicity."""

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
import os
import threading
import unittest
from uuid import uuid4

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from app.core.time.business_time import business_today
from app.db.models import Base
from app.db.models.admin_user import AdminUser
from app.db.models.branch import Branch
from app.db.models.customer_pass import CustomerPass
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_user import MobileUser
from app.db.models.pass_plan import PassPlan
from app.db.models.pass_redemption import PassRedemption
from app.db.models.visit import Visit
from app.db.repositories.branch_repository import BranchRepository
from app.db.repositories.customer_pass_repository import CustomerPassRepository
from app.db.repositories.mobile_child_repository import MobileChildRepository
from app.db.repositories.pass_plan_repository import PassPlanRepository
from app.db.repositories.pass_redemption_repository import PassRedemptionRepository
from app.db.repositories.visit_repository import VisitRepository
from app.modules.passes.qr_service import PassQrService
from app.modules.passes.service import PassService


@unittest.skipUnless(os.getenv('PASS_TEST_DATABASE_URL'), 'set PASS_TEST_DATABASE_URL')
class PostgreSQLPassConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(os.environ['PASS_TEST_DATABASE_URL'], pool_pre_ping=True)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)
        cls.secret = 'p' * 48

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def _seed(self) -> tuple[str, str]:
        suffix = uuid4().hex[:10]
        branch_id, user_id, child_id, admin_id = (f'pass-pg-{suffix}-{x}' for x in ('branch', 'user', 'child', 'admin'))
        plan_id, payment_id, pass_id = (f'pass-pg-{suffix}-{x}' for x in ('plan', 'payment', 'customer'))
        with self.SessionLocal() as db:
            db.add(Branch(id=branch_id, slug=f'pass-pg-{suffix}', name='Pass PG', city='Almaty', address='Test', short_label='PG', working_hours='00:00 - 23:59', description='Test', phone='1', whatsapp_phone='1', gallery_image_urls=[], facilities=[], is_active=True))
            db.add(MobileUser(id=user_id, phone=f'+77{suffix[:10]}', email=f'{suffix}@example.com', is_active=True))
            db.flush()
            db.add(AdminUser(id=admin_id, email=f'{suffix}@admin.example.com', full_name='PG', password_hash='x', role='operator', branch_id=branch_id, is_active=True))
            db.add(MobileChild(id=child_id, user_id=user_id, name='Child', birth_date=business_today(), gender='unspecified'))
            db.add(PassPlan(id=plan_id, name='BOOM 4', price_tenge=10000, visit_limit=4, validity_days=30, daily_limit=1, is_active=True))
            db.flush()
            db.add(MobilePayment(id=payment_id, mobile_user_id=user_id, branch_id=branch_id, payable_entity_type='pass_purchase', payable_entity_id=plan_id, local_order_id=f'pass-pg-order-{suffix}', idempotency_key=f'pass-pg-key-{suffix}', amount_tenge=10000, gross_amount_tenge=10000, cash_amount_tenge=10000, currency='KZT', quantity=1, visit_date=None, ticket_items=[], status='paid', init_payload={}, callback_payload={}))
            db.flush()
            from datetime import timedelta
            now = datetime.now(UTC)
            db.add(CustomerPass(id=pass_id, mobile_user_id=user_id, child_id=child_id, mobile_payment_id=payment_id, pass_plan_id=plan_id, name_snapshot='BOOM 4', price_tenge_snapshot=10000, visit_limit_snapshot=4, validity_days_snapshot=30, daily_limit_snapshot=1, activated_at=now, expires_at=now + timedelta(days=30), remaining_visits=4, status='active'))
            db.commit()
        return branch_id, pass_id

    def _service(self, db: Session) -> PassService:
        return PassService(
            plan_repository=PassPlanRepository(db), customer_pass_repository=CustomerPassRepository(db),
            redemption_repository=PassRedemptionRepository(db), child_repository=MobileChildRepository(db),
            branch_repository=BranchRepository(db), visit_repository=VisitRepository(db),
            qr_service=PassQrService(self.secret),
        )

    def test_two_transactions_redeem_once(self) -> None:
        branch_id, pass_id = self._seed()
        barrier = threading.Barrier(2)

        def run() -> str:
            with self.SessionLocal() as db:
                admin = db.scalar(select(AdminUser).where(AdminUser.branch_id == branch_id))
                barrier.wait()
                response = self._service(db).redeem(
                    qr_payload=PassQrService(self.secret).build_payload(pass_id),
                    branch_id=branch_id, admin_user=admin,
                )
                return response.outcome

        with ThreadPoolExecutor(max_workers=2) as executor:
            outcomes = list(executor.map(lambda _: run(), range(2)))
        self.assertEqual(sorted(outcomes), ['already_used_today', 'redeemed'])
        with self.SessionLocal() as db:
            self.assertEqual(db.query(PassRedemption).filter(PassRedemption.customer_pass_id == pass_id).count(), 1)
            self.assertEqual(db.query(Visit).filter(Visit.mobile_payment_id.is_(None)).count(), 1)
            self.assertEqual(db.get(CustomerPass, pass_id).remaining_visits, 3)


if __name__ == '__main__':
    unittest.main()
