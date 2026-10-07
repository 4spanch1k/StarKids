from datetime import UTC, date, datetime
import unittest

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.models import Base
from app.db.models.branch import Branch
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_user import MobileUser
from app.db.models.visit import Visit
from app.db.repositories.visit_repository import VisitRepository
from app.modules.mobile_payments.visit_finalizer import VisitFinalizer


class VisitFinalizerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            'sqlite://',
            connect_args={'check_same_thread': False},
            poolclass=StaticPool,
        )
        cls.SessionLocal = sessionmaker(
            bind=cls.engine,
            class_=Session,
            expire_on_commit=False,
        )
        Base.metadata.create_all(cls.engine)

    @classmethod
    def tearDownClass(cls) -> None:
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(Visit).delete()
            session.query(MobilePayment).delete()
            session.query(MobileUser).delete()
            session.query(Branch).delete()
            session.add(
                Branch(
                    id='finalizer-branch', slug='finalizer-branch', name='Finalizer',
                    city='Almaty', address='Test', short_label='Test',
                    working_hours='10:00 - 20:00', description='Test', phone='1',
                    whatsapp_phone='1', gallery_image_urls=[], facilities=[],
                    display_order=1, is_active=True,
                )
            )
            session.add(MobileUser(id='finalizer-user', phone='70000000000'))
            session.flush()
            session.add(
                MobilePayment(
                    id='finalizer-payment', mobile_user_id='finalizer-user',
                    branch_id='finalizer-branch',
                    payable_entity_type='branch_ticket_order',
                    payable_entity_id='finalizer-branch',
                    local_order_id='finalizer-order', idempotency_key='finalizer-key',
                    amount_tenge=100, currency='KZT', quantity=1,
                    visit_date=date(2026, 9, 17), ticket_items=[], status='paid',
                    init_payload={}, callback_payload={},
                )
            )
            session.add(
                Visit(
                    id='finalizer-visit', mobile_payment_id='finalizer-payment',
                    mobile_user_id='finalizer-user', branch_id='finalizer-branch',
                    status='active', started_at=datetime(2026, 9, 17, 11, tzinfo=UTC),
                )
            )
            session.commit()

    def test_due_visit_is_completed_and_retry_is_idempotent(self) -> None:
        now = datetime(2026, 9, 18, 8, tzinfo=UTC)
        with self.SessionLocal() as session:
            finalizer = VisitFinalizer(
                repository=VisitRepository(session), now_provider=lambda: now,
            )
            self.assertEqual(finalizer.finalize_due_visits(), 1)
            self.assertEqual(finalizer.finalize_due_visits(), 0)
            visit = session.get(Visit, 'finalizer-visit')
            self.assertEqual(visit.status, 'completed')
            self.assertEqual(visit.completion_reason, 'validity_cutoff')

    def test_visit_before_cutoff_stays_active(self) -> None:
        now = datetime(2026, 9, 17, 14, tzinfo=UTC)
        with self.SessionLocal() as session:
            finalizer = VisitFinalizer(
                repository=VisitRepository(session), now_provider=lambda: now,
            )
            self.assertEqual(finalizer.finalize_due_visits(), 0)
            self.assertEqual(session.get(Visit, 'finalizer-visit').status, 'active')


if __name__ == '__main__':
    unittest.main()
