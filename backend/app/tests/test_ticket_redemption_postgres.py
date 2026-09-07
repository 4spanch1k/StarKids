"""Admission race tests against a real PostgreSQL database.

Run with ADMISSION_TEST_DATABASE_URL pointing at a disposable database that
has ``alembic upgrade head`` applied.
"""

from concurrent.futures import ThreadPoolExecutor
from datetime import date
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
from app.db.models.issued_ticket import IssuedTicket
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_user import MobileUser
from app.db.models.ticket_redemption import TicketRedemption
from app.db.models.visit import Visit
from app.db.repositories.branch_repository import BranchRepository
from app.db.repositories.issued_ticket_repository import IssuedTicketRepository
from app.db.repositories.mobile_payment_repository import MobilePaymentRepository
from app.db.repositories.ticket_redemption_repository import TicketRedemptionRepository
from app.db.repositories.visit_repository import VisitRepository
from app.modules.admin_tickets.service import TicketRedemptionService
from app.modules.mobile_payments.ticket_qr_service import TicketQrService


@unittest.skipUnless(os.getenv('ADMISSION_TEST_DATABASE_URL'), 'set ADMISSION_TEST_DATABASE_URL')
class PostgreSQLAdmissionConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(os.environ['ADMISSION_TEST_DATABASE_URL'], pool_pre_ping=True)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)
        cls.secret = 'p' * 48

    @classmethod
    def tearDownClass(cls) -> None:
        cls.engine.dispose()

    def _seed(self, *, two_tickets: bool) -> tuple[str, list[str]]:
        suffix = uuid4().hex
        short = suffix[:18]
        payment_id = f'pg-payment-{short}'
        branch_id = f'pg-branch-{short}'
        user_id = f'pg-user-{short}'
        admin_id = f'pg-admin-{short}'
        ticket_ids = [f'pg-ticket-{short}-{index}' for index in range(2 if two_tickets else 1)]
        with self.SessionLocal() as db:
            db.add(Branch(id=branch_id, slug=f'pg-{suffix}', name='PG', city='Almaty', address='Test', short_label='PG', working_hours='11:00 - 23:00', description='Test', phone='1', whatsapp_phone='1', gallery_image_urls=[], facilities=[], is_active=True))
            db.add(MobileUser(id=user_id, phone=f'+77{suffix[:10]}', email=f'{suffix}@example.com', password_hash='x', is_active=True))
            # Materialize the referenced branch before inserting the newly
            # scoped operator; PostgreSQL does not infer dependency ordering
            # from plain scalar foreign-key assignments.
            db.flush()
            db.add(AdminUser(id=admin_id, email=f'{suffix}@admin.example.com', full_name='PG', password_hash='x', role='operator', branch_id=branch_id, is_active=True))
            db.flush()
            db.add(MobilePayment(id=payment_id, mobile_user_id=user_id, branch_id=branch_id, payable_entity_type='branch_ticket_order', payable_entity_id=branch_id, local_order_id=f'pg-order-{suffix}', idempotency_key=f'pg-key-{suffix}', amount_tenge=1000, currency='KZT', quantity=len(ticket_ids), visit_date=business_today(), ticket_items=[], status='paid', init_payload={}, callback_payload={}))
            db.flush()
            for index, ticket_id in enumerate(ticket_ids):
                db.add(IssuedTicket(id=ticket_id, mobile_payment_id=payment_id, ticket_number=f'PG-{suffix[:8]}-{index}', ticket_item_id='item', title_snapshot='Admission', price_tenge=1000, branch_id=branch_id, visit_date=business_today(), line_index=index, status='issued'))
            db.commit()
        return branch_id, ticket_ids

    def _service(self, db: Session) -> TicketRedemptionService:
        return TicketRedemptionService(issued_ticket_repository=IssuedTicketRepository(db), redemption_repository=TicketRedemptionRepository(db), payment_repository=MobilePaymentRepository(db), visit_repository=VisitRepository(db), branch_repository=BranchRepository(db), ticket_qr_service=TicketQrService(self.secret))

    def _race(self, branch_id: str, ticket_ids: list[str]) -> list[str]:
        barrier = threading.Barrier(2)
        def run(ticket_id: str) -> str:
            with self.SessionLocal() as db:
                barrier.wait()
                response = self._service(db).redeem(qr_payload=TicketQrService(self.secret).build_payload(ticket_id), branch_id=branch_id, admin_user=db.scalar(select(AdminUser).where(AdminUser.role == 'operator', AdminUser.branch_id == branch_id)))
                return response.outcome
        with ThreadPoolExecutor(max_workers=2) as executor:
            return list(executor.map(run, ticket_ids))

    def test_same_ticket_has_one_success_over_repeated_races(self) -> None:
        for _ in range(10):
            branch_id, ticket_ids = self._seed(two_tickets=False)
            outcomes = self._race(branch_id, [ticket_ids[0], ticket_ids[0]])
            with self.SessionLocal() as db:
                self.assertEqual(sorted(outcomes), ['already_used', 'redeemed'])
                self.assertEqual(db.query(TicketRedemption).filter(TicketRedemption.issued_ticket_id == ticket_ids[0]).count(), 1)
                self.assertEqual(db.query(Visit).filter(Visit.branch_id == branch_id).count(), 1)

    def test_different_tickets_same_payment_share_one_visit(self) -> None:
        for _ in range(10):
            branch_id, ticket_ids = self._seed(two_tickets=True)
            outcomes = self._race(branch_id, ticket_ids)
            with self.SessionLocal() as db:
                self.assertEqual(outcomes, ['redeemed', 'redeemed'])
                redemptions = db.query(TicketRedemption).filter(TicketRedemption.issued_ticket_id.in_(ticket_ids)).all()
                self.assertEqual(len(redemptions), 2)
                self.assertEqual(len({item.visit_id for item in redemptions}), 1)
                self.assertEqual(db.query(Visit).filter(Visit.branch_id == branch_id).count(), 1)


if __name__ == '__main__':
    unittest.main()
